#!/usr/bin/env python3

""" docker-mock.py is docker mock approximation for testing purposes """

# imports
import argparse
import copy
import json
import os.path

import yaml

# constants
STATE_FILE = os.path.join(os.path.dirname(__file__), 'docker-mock-state.yaml')

# local functions
def load_state(file=STATE_FILE):
    """ reads docker state"""
    with open(file, 'r') as file_handle:
        return yaml.load(file_handle, Loader=yaml.SafeLoader)

def store_state(state, file=STATE_FILE):
    """ store docker state"""
    with open(file, 'w') as file_handle:
        return yaml.dump(state, file_handle)

def action_info():
    """ docker info action"""
    print("%s info" % os.path.basename(__file__))

def action_login(registry_url, user=None):
    """ docker login action, intentionally no-op """
    pass

def action_pull(image):
    """ docker pull action, marks image locally available """
    state = load_state()
    assert image in state['images'], 'Unknown Image %s!' % image
    state['images'][image]['storage']['local'] = True
    store_state(state)

def action_push(image):
    """ docker push, marks image remotely available """
    state = load_state()
    assert image in state['images'], 'Unknown Image %s!' % image
    assert state['images'][image]['storage']['local'], 'Image %s not available locally!' % image
    state['images'][image]['storage']['remote'] = True
    store_state(state)

def action_tag(src_image, dst_image):
    """ docker tag, alias locally available image under new name """
    state = load_state()
    assert src_image in state['images'], 'Unknown Image %s!' % src_image
    assert state['images'][src_image]['storage']['local'], \
      'Image %s not available locally!' % src_image
    state['images'][dst_image] = copy.deepcopy(state['images'][src_image])
    state['images'][dst_image]['storage']['remote'] = False
    store_state(state)

def action_inspect(image):
    """ docker inspect, provides details about locally available image """
    state = load_state()
    assert image in state['images'], 'Unknown Image %s!' % image
    assert state['images'][image]['storage']['local'], 'Image %s not available locally!' % image
    print(json.dumps([{'Id': '42', 
                       'RepoDigests': ['%s@%s' % (image, state['images'][image]['digest'])]}]))

def action_images(format, digests):
    """ docker images action, list docker images """
    state = load_state()
    images = state['images']
    cmd_output = [f"{i} {images[i]['digest']}" for i in images]
    print("\n".join(cmd_output))

def get_cmdline_parser():
    """ return command-line parser """
    parser = argparse.ArgumentParser(prog=os.path.basename(__file__))
    subparsers = parser.add_subparsers(dest='action', help='action help')
    parser_info = subparsers.add_parser('info', help='info')
    parser_login = subparsers.add_parser('login', help='login to registry')
    parser_login.add_argument('registry_url', type=str, help='registry url')
    parser_login.add_argument('-u', '--user', type=str, help='user')
    parser_push = subparsers.add_parser('push', help='push the image to the registry')
    parser_push.add_argument('image', type=str, help='image')
    parser_pull = subparsers.add_parser('pull', help='pull the image from a registry')
    parser_pull.add_argument('image', type=str, help='image')
    parser_inspect = subparsers.add_parser('inspect', help='inspect the image')
    parser_inspect.add_argument('image', type=str, help='image')
    parser_tag = subparsers.add_parser('tag', help='alias the image under new image name')
    parser_tag.add_argument('src_image', type=str, help='source image')
    parser_tag.add_argument('dst_image', type=str, help='destination image')
    parser_images = subparsers.add_parser('images', help='List images')
    parser_images.add_argument('--format', type=str, help='Pretty-print images using a Go template')
    parser_images.add_argument('--digests', action='store_true', help='Show digests')

    return parser

# parse the command-line arguments
ARGS = get_cmdline_parser().parse_args()

# call appropriate action
ACTION_ARGS = vars(ARGS)
ACTION_FUNC_NAME = 'action_%s' % ACTION_ARGS['action']
del ACTION_ARGS['action']
locals()[ACTION_FUNC_NAME](**ACTION_ARGS)
