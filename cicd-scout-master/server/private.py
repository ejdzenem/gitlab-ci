""" Docstring
"""

import logging as log

from flask import Flask, jsonify, make_response

# CONFFILE = os.environ.get("CONFFILE", '/app/conf/vassals/private.ini')

app = Flask(__name__)
# utils.setup_logging(app.cfg)
log.info("Config and logger initialized")


@app.route("/test")
def test():
    """ test
    """
    return make_response(jsonify({"code": 200, "message":"Nope!"}), 200)


@app.route("/")
def monitoring():
    """ root
    """
    return make_response(jsonify({"code": 200, "message":"OK"}), 200)
