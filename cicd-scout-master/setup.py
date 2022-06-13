import shutil
import subprocess

from setuptools import setup


setup(
    name                = "cicd-scout",
    description         = "Gitlab CI/CD test",
    author              = "Mapy",
    author_email        = "mapy.vyvoj@firma.seznam.cz",
    maintainer          = "Mapy Vyvoj",
    maintainer_email    = "mapy.vyvoj@firma.seznam.cz",
    url                 = "https://gitlab.seznam.net/tomas.sekanina/cicd-scout",
    packages            = ['server'],
    license             = "Proprietary License",
    classifiers         = [
        "License :: Other/Proprietary License",
        "Programming Language :: Python :: 3",
        "Topic :: Internet :: WWW/HTTP",
    ],
    setup_requires = [
        "pytest-runner"
    ],
    install_requires = [
        "flask>=0.12",
        "requests",
        "openapi-core",
        "uwsgi",
    ],
    tests_require = [
        "pytest"
    ],
    include_package_data = True,
)
