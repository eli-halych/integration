#!/usr/bin/env python3

# ============LICENSE_START=======================================================
#  Copyright (C) 2020 Nordix Foundation.
# ================================================================================
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0
# ============LICENSE_END=========================================================

__author__ = "Eliezio Oliveira <eliezio.oliveira@est.tech>"
__copyright__ = "Copyright (C) 2020 Nordix Foundation"
__license__ = "Apache 2.0"

import os
import time
from threading import Timer

import sysrepo as sr
from loguru import logger

YANG_MODULE_NAME = 'pnf-sw-upgrade'

XPATH_CTX = sr.Xpath_Ctx()
PAUSE_TO_LOCK = 0.5

#
# ----- BEGIN Finite State Machine definitions -----
#

# Actions
ACT_PRE_CHECK = 'PRE_CHECK'
ACT_DOWNLOAD_NE_SW = 'DOWNLOAD_NE_SW'
ACT_ACTIVATE_NE_SW = 'ACTIVATE_NE_SW'
ACT_CANCEL = 'CANCEL'

# States
ST_CREATED = 'CREATED'
ST_INITIALIZED = 'INITIALIZED'
ST_DOWNLOAD_IN_PROGRESS = 'DOWNLOAD_IN_PROGRESS'
ST_DOWNLOAD_COMPLETED = 'DOWNLOAD_COMPLETED'
ST_ACTIVATION_IN_PROGRESS = 'ACTIVATION_IN_PROGRESS'
ST_ACTIVATION_COMPLETED = 'ACTIVATION_COMPLETED'

# Timeouts used for timed transitions
SWUG_TIMED_TRANSITION_TO = int(os.environ.get("SWUG_TIMED_TRANSITION_TO", "7"))
TO_DOWNLOAD = SWUG_TIMED_TRANSITION_TO
TO_ACTIVATION = SWUG_TIMED_TRANSITION_TO


def timestamper(sess, key_id):
    xpath = xpath_of(key_id, 'state-change-time')
    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    state = sr.Val(now, sr.SR_STRING_T)
    sess.set_item(xpath, state)


def xpath_of(key_id, leaf_id):
    selector = "[id='{0}']".format(key_id) if key_id else ''
    return "/%s:software-upgrade/upgrade-package%s/%s" % (YANG_MODULE_NAME, selector, leaf_id)


"""
The finite state machine (FSM) is represented as a dictionary where the current state is the key, and its value is
an object (also represented as a dictionary) with the following optional attributes:

- on_enter: a function called when FSM enters this state;
- transitions: a dictionary mapping every acceptable action to the target state;
- timed_transition: a pair for a timed transition that will automatically occur after a given interval.
"""
STATE_MACHINE = {
    ST_CREATED: {
        'transitions': {ACT_PRE_CHECK: ST_INITIALIZED}
    },
    ST_INITIALIZED: {
        'on_enter': timestamper,
        'transitions': {ACT_DOWNLOAD_NE_SW: ST_DOWNLOAD_IN_PROGRESS}
    },
    ST_DOWNLOAD_IN_PROGRESS: {
        'on_enter': timestamper,
        'timed_transition': (TO_DOWNLOAD, ST_DOWNLOAD_COMPLETED),
        'transitions': {ACT_CANCEL: ST_INITIALIZED}
    },
    ST_DOWNLOAD_COMPLETED: {
        'on_enter': timestamper,
        'transitions': {ACT_ACTIVATE_NE_SW: ST_ACTIVATION_IN_PROGRESS}
    },
    ST_ACTIVATION_IN_PROGRESS: {
        'on_enter': timestamper,
        'timed_transition': (TO_ACTIVATION, ST_ACTIVATION_COMPLETED),
        'transitions': {ACT_CANCEL: ST_DOWNLOAD_COMPLETED}
    },
    ST_ACTIVATION_COMPLETED: {
        'on_enter': timestamper,
        'transitions': {ACT_ACTIVATE_NE_SW: ST_ACTIVATION_IN_PROGRESS}
    }
}


#
# ----- END Finite State Machine definitions -----
#


def main():
    try:
        conn = sr.Connection(YANG_MODULE_NAME)
        sess = sr.Session(conn)
        subscribe = sr.Subscribe(sess)

        subscribe.module_change_subscribe(YANG_MODULE_NAME, module_change_cb, conn)

        try:
            print_current_config(sess, YANG_MODULE_NAME)
        except Exception as e:
            logger.error(e)

        sr.global_loop()

        logger.info("Application exit requested, exiting.")
    except Exception as e:
        logger.error(e)


# Function to be called for subscribed client of given session whenever configuration changes.
def module_change_cb(sess, module_name, event, private_ctx):
    if event == sr.SR_EV_APPLY:
        try:
            conn = private_ctx
            change_path = xpath_of(None, 'action')
            it = sess.get_changes_iter(change_path)
            while True:
                change = sess.get_change_next(it)
                if change is None:
                    break
                op = change.oper()
                if op in (sr.SR_OP_CREATED, sr.SR_OP_MODIFIED):
                    handle_trigger_action(conn, sess, change.new_val())
        except Exception as e:
            logger.error(e)
    return sr.SR_ERR_OK


# Function to print current configuration state.
# It does so by loading all the items of a session and printing them out.
def print_current_config(session, module_name):
    select_xpath = f"/{module_name}:*//*"
    values = session.get_items(select_xpath)
    if values:
        logger.info("========== BEGIN CONFIG ==========")
        for i in range(values.val_cnt()):
            logger.info(values.val(i).to_string().strip())
        logger.info("=========== END CONFIG ===========")


def handle_trigger_action(conn, sess, action_val):
    """
    Handle individual changes on the model.
    """
    logger.info("CREATED/MODIFIED: %s" % action_val.to_string())
    xpath = action_val.xpath()
    last_node = XPATH_CTX.last_node(xpath)
    # Warning: 'key_value' modifies 'xpath'!
    key_id = XPATH_CTX.key_value(xpath, 'upgrade-package', 'id')
    if key_id and last_node == 'action':
        action = action_val.data().get_enum()
        cur_state = sess.get_item(xpath_of(key_id, 'current-status')).data().get_enum()
        next_state_str = STATE_MACHINE[cur_state]['transitions'].get(action, None)
        if next_state_str:
            Timer(PAUSE_TO_LOCK, try_change_state, (conn, key_id, next_state_str)).start()


def try_change_state(conn, key_id, state_str):
    sess = sr.Session(conn)
    try:
        try:
            sess.lock_module(YANG_MODULE_NAME)
        except RuntimeError:
            logger.warning(f"Retrying after {PAUSE_TO_LOCK}s")
            Timer(PAUSE_TO_LOCK, try_change_state, (conn, key_id, state_str)).start()
            return
        try:
            state = sr.Val(state_str, sr.SR_ENUM_T)
            sess.set_item(xpath_of(key_id, 'current-status'), state)
            on_enter = STATE_MACHINE[state_str].get('on_enter', None)
            if callable(on_enter):
                on_enter(sess, key_id)
            sess.commit()
        finally:
            sess.unlock_module(YANG_MODULE_NAME)
        delay, next_state_str = STATE_MACHINE[state_str].get('timed_transition', [0, None])
        if delay:
            Timer(delay, try_change_state, (conn, key_id, next_state_str)).start()
    finally:
        sess.session_stop()


if __name__ == '__main__':
    main()
