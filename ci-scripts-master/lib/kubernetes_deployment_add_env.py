#!/usr/bin/env python3
import sys
import argparse
from  ruamel import yaml
import io


class BadEnvFormatException(Exception):
    """Exception raised if line in env file does not contains '='

    Args:
        line (int): line number
        data (str): non-matched text
    """
    def __init__(self, line, data):
        self.line = line
        self.data = data


class NotDeploymentException(Exception):
    """Exception raised if manifest kind is not 'Deployment'"""
    pass


class BadDeploymentFormatException(Exception):
    """Exception raised if manifest does not contains any containers (path .spec.template.spec.containers)"""
    pass


class ContainerNotFoundException(Exception):
    """Exception raised if --container-name is not present in manifest"""
    pass


class ContainerNameNotSetException(Exception):
    """Exception raised if manifest contains multiple containers and --container-name param is not set"""
    pass


class OverwriteDisabledException(Exception):
    """Exception raised if container contains environment variable which is already set in manifest
    and --allow-env-overwrite is not set
    """
    def __init__(self, variable):
        self.variable = variable


def get_env_vars(env_file, prefix):
    """Reads env file and returns dict of env variables

    If multiple env variables with same name is present, last is applied

    Args:
        env_file (str): name of environment file to parse
        prefix (str): parse only environment variables with name staring with prefix

    Returns:
        dict: env variables

    """

    with open(env_file) as f:
        result = {}
        for ln, line in enumerate(f):
            line = line.strip()
            # skip empty lines and comments
            if not line or line.startswith('#'):
                continue

            if '=' not in line:
                raise BadEnvFormatException(ln, line)

            env_name, env_value = line.split('=', 1)

            if len(env_value) > 0:
                quoted = env_value[0] == env_value[-1] in ['"', "'"]
                if quoted:
                    env_value = env_value[1:-1]

            result[env_name] = env_value

        return result


def update_deployment(raw, env_variables, container, allow_overwrite):
    """Update env variables in containers in deployment

    Args:
        raw (str): manifest raw document (yaml format)
        env_variables (dict): dictionary of enviroment variables to update
        container (str): container to update
        allow_overwrite (bool): allow overriding existing variables

    Returns:
        string: updated raw manifest

    """
    data = yaml.round_trip_load(raw)

    if data.get('kind', None) != "Deployment":
        raise NotDeploymentException

    try:
        containers = {c['name']: c for c in data['spec']['template']['spec']['containers']}
    except KeyError:
        raise BadDeploymentFormatException

    mycontainer = None

    if len(containers) == 1 and container is None:
        mycontainer = containers[list(containers.keys()).pop()]
    elif container:
        mycontainer = containers.get(container, None)
        if not mycontainer:
            raise ContainerNotFoundException
    else:
        raise ContainerNameNotSetException

    if mycontainer.get('env') is None:
        mycontainer['env'] = []

    # check duplicit env variables + replace existing
    for env_data in mycontainer['env']:
        if env_data['name'] not in env_variables.keys():
            continue

        if allow_overwrite:
            env_data['value'] = env_variables[env_data['name']]
            env_variables.pop(env_data['name'])
        else:
            raise OverwriteDisabledException(env_data['name'])

    for name, value in env_variables.items():
        mycontainer['env'].append({'name': name, 'value': value})

    output = io.StringIO()
    yaml.round_trip_dump(data, output)

    return output.getvalue()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Append env variables to deployment manifest')
    parser.add_argument('--env-file', type=str, help='environment file path', required=True)
    parser.add_argument('--deployment-file', type=str, help='deployment manifest path', required=True)
    parser.add_argument('--container-name', type=str, required=False, default=None,
                        help='container name (required if manifest contains multiple containers)')
    parser.add_argument('--env-prefix', type=str, default=None, help='append only env with specific prefix')
    parser.add_argument('--allow-env-overwrite', type=str, default=False,
                        help='allow overwriting env variables')

    args = parser.parse_args()
    try:

        envs = get_env_vars(args.env_file, args.env_prefix)

        with open(args.deployment_file) as f:
            raw_data = f.read()

        print(update_deployment(raw_data, envs, args.container_name, args.allow_env_overwrite))

    except BadEnvFormatException as e:
        print("Bad env format '{}' in file '{}' on line '{}".format(e.data, args.env_file, e.line), file=sys.stderr)
        exit(1)

    except NotDeploymentException as e:
        print("File '{}' is not deployment manifest".format(args.deployment_file), file=sys.stderr)
        exit(1)

    except BadDeploymentFormatException as e:
        print("Deployment manifest '{}' does not contain path '.spec.template.spec.containers'".format(args.deployment_file), file=sys.stderr)
        exit(1)

    except ContainerNotFoundException as e:
        print("Container '{}' not found in manifest '{}'".format(args.container_name, args.deployment_file), file=sys.stderr)
        exit(1)

    except OverwriteDisabledException as e:
        print("Trying to overwrite variable '{}', but variable overwriting is not allowed".format(e.variable), file=sys.stderr)
        exit(1)

    except ContainerNameNotSetException as e:
        print("Multiple containers found in manifest, but --container-name was not set.", file=sys.stderr)
        exit(1)