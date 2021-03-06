=====================
 SSL endpoints check
=====================

Utility for checking if all of the ports exposed outside of Kubernetes cluster
use SSL tunnels.

Prerequisites
-------------

Configuration
~~~~~~~~~~~~~

``-kubeconfig``
  Optional unless ``$HOME`` is not set. Defaults to ``$HOME/.kube/config``.

``-xfail``
  Optional list of services with corresponding NodePorts which do not use SSL
  tunnels. These ports are known as "expected failures" and will not be
  checked.

Dependencies
~~~~~~~~~~~~

- nmap_

.. _nmap: https://nmap.org/book/install.html

Build (local)
~~~~~~~~~~~~~

- go_ (1.11+, tested on 1.13)

.. _go: https://golang.org/doc/install

Build (Docker)
~~~~~~~~~~~~~~

- Docker_ engine
- make (optional)

.. _Docker: https://docs.docker.com/install

Test
~~~~

- Ginkgo_
- GolangCI-Lint_ (optional)

.. _Ginkgo: https://onsi.github.io/ginkgo/#getting-ginkgo
.. _GolangCI-Lint: https://github.com/golangci/golangci-lint#install

Building
--------

Command (local)
~~~~~~~~~~~~~~~

.. code-block:: shell

    $ mkdir bin
    $ go build -o bin/sslendpoints

Additional ``bin`` directory and specifying ``go build`` output are used to
declutter project and maintain compatibility with Docker-based process. Running
``go build`` without parameters will create ``sslendpoints`` binary in current
directory.

Command (Docker)
~~~~~~~~~~~~~~~~

.. code-block:: shell

    $ make # or commands from corresponding "make" targets


Running
-------

Command (local)
~~~~~~~~~~~~~~~

.. code-block:: shell

    $ bin/sslendpoints [-kubeconfig KUBECONFIG] [-xfail XFAIL]

Command (Docker)
~~~~~~~~~~~~~~~~

.. code-block:: shell

    $ docker run --rm --volume $KUBECONFIG:/.kube/config \
        sslendpoints-build-img /bin/sslendpoints

    $ docker run --rm --volume $KUBECONFIG:/opt/config \
        sslendpoints-build-img /bin/sslendpoints -kubeconfig /opt/config

    $ docker run --rm \
        --volume $KUBECONFIG:/opt/config \
        --volume $XFAIL:/opt/xfail \
        sslendpoints-build-img /bin/sslendpoints \
            -kubeconfig /opt/config
            -xfail /opt/xfail

Output
~~~~~~

.. code-block:: shell

    $ ./sslendpoints -kubeconfig ~/.kube/config.onap
    2020/03/17 10:40:29 Host 192.168.2.10
    2020/03/17 10:40:29 PORT        SERVICE
    2020/03/17 10:40:29 30203       sdnc-dgbuilder
    2020/03/17 10:40:29 30204       sdc-be
    2020/03/17 10:40:29 30207       sdc-fe
    2020/03/17 10:40:29 30220       aai-sparky-be
    2020/03/17 10:40:29 30226       message-router
    2020/03/17 10:40:29 30233       aai
    2020/03/17 10:40:29 30256       sdc-wfd-fe
    2020/03/17 10:40:29 30257       sdc-wfd-be
    2020/03/17 10:40:29 30264       sdc-dcae-fe
    2020/03/17 10:40:29 30266       sdc-dcae-dt
    2020/03/17 10:40:29 30279       aai-babel
    2020/03/17 10:40:29 30406       so-vnfm-adapter
    2020/03/17 10:40:29 There are 12 non-SSL NodePorts in the cluster


Testing
-------

.. code-block:: shell

    $ go test ./...     # basic
    $ ginkgo -r         # pretty
    $ golangci-lint run # linters
