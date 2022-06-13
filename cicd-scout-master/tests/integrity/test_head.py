""" Test
"""

import os

import requests

URL = os.environ.get("URL")

def test_head():
    """ test head
    """
    resp = requests.head(URL)
    assert resp.status_code == 200

def test_get():
    """ test get
    """
    resp = requests.get(URL)
    assert resp.status_code == 200
