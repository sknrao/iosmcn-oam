FROM alpine:latest
WORKDIR /
RUN mkdir -p /Sphinx/build

RUN apk add --no-cache python3 py3-pip make git
RUN pip3 install git+https://github.com/sphinx-doc/sphinx --break-system-packages && \
    pip3 install sphinx-autobuild --break-system-packages

ADD ./docs/requirements-docs.txt /Sphinx

RUN pip3 install -r /Sphinx/requirements-docs.txt --break-system-packages

CMD sphinx-autobuild -b html -n --host 0.0.0.0 --port 80 /Sphinx/source /Sphinx/build
