import requests # pylint: disable=W0611
from uuid import uuid4
import ProvMnSProvider
import logging
from json import dumps # pylint: disable=W0611

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

MOI_ID = str(uuid4())
MOI_CLASS = ProvMnSProvider.Cretaed_MOIs_list[0]['class']
MOI_DATA_TMPL = { 'data': ProvMnSProvider.Cretaed_MOIs_list[0] }
MOI_DATA_PATCH = { "data": { "pLMNId": "xxx", "gNBId": "1234", "gNBIdLength": "4" }}
URI_SCHEMA = 'http'
AUTH_STRING = (ProvMnSProvider.username, ProvMnSProvider.password)
URI_BASE_STRING = URI_SCHEMA + '://' + ProvMnSProvider.ipAddress + ':' + \
             str(ProvMnSProvider.portNumber) + ProvMnSProvider.prefix + \
             '/' + MOI_CLASS + '/' + MOI_ID
URI_PUT_STRING = URI_BASE_STRING
URI_GET_STRING = URI_BASE_STRING + '?scope=BASE_ONLY&filter=' + MOI_CLASS + \
                 '&fields=gNBId&fields=gNBIdLength'
URI_PATCH_STRING = URI_BASE_STRING + '?scope=BASE_ONLY&filter=' + MOI_CLASS
URI_DELETE_STRING = URI_PATCH_STRING
