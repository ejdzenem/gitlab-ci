#!/usr/bin/env python3
import unittest
import tempfile
from ruamel import yaml

from lib.kubernetes_deployment_add_env import get_env_vars, update_deployment
from lib.kubernetes_deployment_add_env import BadEnvFormatException, OverwriteDisabledException,\
    ContainerNotFoundException, ContainerNameNotSetException


class TestGetEnv(unittest.TestCase):

    @staticmethod
    def _mk_tempfile(test_data):
        with tempfile.NamedTemporaryFile('a+', delete=False) as tmp_file:
            tmp_file.write("\n".join(test_data))
            tmp_file_name = tmp_file.name
        return tmp_file_name

    def _test_data(self, test_data, test_result):
        tmp_file_name = self._mk_tempfile(test_data)
        env_data = get_env_vars(tmp_file_name, "")
        self.assertDictEqual(env_data, test_result, msg="Env file: {}".format(tmp_file_name))

    def _test_exception(self, test_data, test_result):
        tmp_file_name = self._mk_tempfile(test_data)

        with self.assertRaises(test_result):
            get_env_vars(tmp_file_name, "")

    def test_equal_sign_in_value(self):
        """Test if equal sign in env value does not break anything"""
        data = ["test=test", "A=aaa-a=123_b"]
        result = {"test": "test", "A": "aaa-a=123_b"}
        self._test_data(data, result)

    def test_quoted_value(self):
        """Test if value can be quoted"""
        data = ["test=test", "A='data data'"]
        result = {"test": "test", "A": "data data"}
        self._test_data(data, result)

    def test_doublequoted_value(self):
        """Test if value can be double quoted"""
        data = ["test=test", "A=\"data data\""]
        result = {"test": "test", "A": "data data"}
        self._test_data(data, result)

    def test_empty_line(self):
        """Test if empty line is skipped"""
        data = ["test=test", "", "A=aaaa"]
        result = {"test": "test", "A": "aaaa"}
        self._test_data(data, result)

    def test_comment_full_line(self):
        """Test if comment is skipped"""
        data = ["test=test", "#this line do nithing just comment"]
        result = {"test": "test"}
        self._test_data(data, result)

    def test_quote_in_value(self):
        """Test quote character in double quoted data"""
        data = ["test=test", "A=\"data 'data\""]
        result = {"test": "test", "A": "data 'data"}
        self._test_data(data, result)

    def test_escaped_quote_in_value(self):
        """Test escaped quote char in quoted data"""
        data = ["test=test", "A='data \'data'"]
        result = {"test": "test", "A": "data 'data"}
        self._test_data(data, result)

    def test_missing_equal_sign(self):
        """Test exception for missing equal sign"""
        data = ["testtest"]
        result = BadEnvFormatException
        self._test_exception(data, result)

    def test_same_env_name(self):
        """Test multiple env variables with same name"""
        data = ["test=test", "a=1", "a=2"]
        result = {"test": "test", "a": "2"}
        self._test_data(data, result)


class TestGenerateManifest(unittest.TestCase):

    @staticmethod
    def _get_raw_manifest(file):
        with open(file) as f:
            raw_data = f.read()
        return raw_data

    def _test_deployment_env(self, original_manifest, expected_result, env_variables, container=None, allow_overwrite=False):
        original_manifest_raw = self._get_raw_manifest(original_manifest)
        updated_manifest_raw = update_deployment(original_manifest_raw, env_variables, container, allow_overwrite)

        updated_dict = yaml.safe_load(updated_manifest_raw)
        expected_dict = yaml.safe_load(self._get_raw_manifest(expected_result))

        self.assertDictEqual(updated_dict, expected_dict)

    def test_add_env_c1(self):
        """Test adding env to first container"""
        manifest = "test/test_files/kubernetes_deployment.yaml"
        expected_result = "test/test_files/kubernetes_deployment_test1.yaml"
        env_variables = {"c1e3": "value3"}

        self._test_deployment_env(manifest, expected_result, env_variables, container="container1")

    def test_add_env_c2(self):
        """Test adding env to second container"""
        manifest = "test/test_files/kubernetes_deployment.yaml"
        expected_result = "test/test_files/kubernetes_deployment_test2.yaml"
        env_variables = {"c2e3": "value3"}

        self._test_deployment_env(manifest, expected_result, env_variables, container="container2")

    def test_add_env_one_container(self):
        """Test adding env to deployment, which contains only one container"""
        manifest = "test/test_files/kubernetes_deployment_one_container.yaml"
        expected_result = "test/test_files/kubernetes_deployment_test3.yaml"
        env_variables = {"c1e3": "value3"}

        self._test_deployment_env(manifest, expected_result, env_variables)

    def test_overwrite_success(self):
        """Test overwriting variable with enabling overwriting"""
        manifest = "test/test_files/kubernetes_deployment_one_container.yaml"
        expected_result = "test/test_files/kubernetes_deployment_test4.yaml"
        env_variables = {"c1e2": "value3"}

        self._test_deployment_env(manifest, expected_result, env_variables, allow_overwrite=True)

    def test_overwrite_failed(self):
        """Test overwriting variable with disabled overwriting"""
        manifest = "test/test_files/kubernetes_deployment_one_container.yaml"
        expected_result = "test/test_files/kubernetes_deployment_test4.yaml"
        env_variables = {"c1e2": "value3"}

        with self.assertRaises(OverwriteDisabledException):
            self._test_deployment_env(manifest, expected_result, env_variables, allow_overwrite=False)

    def test_container_not_found(self):
        """Test exception on non-existing container"""
        manifest = "test/test_files/kubernetes_deployment.yaml"
        expected_result = "test/test_files/kubernetes_deployment.yaml"
        env_variables = {}

        with self.assertRaises(ContainerNotFoundException):
            self._test_deployment_env(manifest, expected_result, env_variables, container="non_existing_container")

    def test_container_name_not_set(self):
        """Test deployment with multiple containers, but container name not set"""
        manifest = "test/test_files/kubernetes_deployment.yaml"
        expected_result = "test/test_files/kubernetes_deployment.yaml"
        env_variables = {}

        with self.assertRaises(ContainerNameNotSetException):
            self._test_deployment_env(manifest, expected_result, env_variables)