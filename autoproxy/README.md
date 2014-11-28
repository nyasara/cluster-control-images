azure-autoproxy
===============

Automated build repo for docker image that provides an nginx proxy that automatically discovers services

This image can be found at [insert link to nyasara/azure-autoproxy on Docker hub]

This image is intended for use with my family of images for running a CoreOS cluster on Microsoft Azure

* [link to nyasara/azure-registry] - private registry backed by Azure storage and run internally
* [link to nyasara/azure-corestrap] - reads a config file and automatically syncs it to etcd
* [link to nyasara/azure-librarian] - downloads git repos, builds docker containers of them, and uploads to <azure-registry>
* [link to nyasara/azure-foreman] - reads data put into etcd by azure-corestrap and uses it to manage fleet units
* [link to nyasara/azure-planner] - downloads configuration data by syncing a git repo(s) to your Azure cluster
* [link to nyasara/azure-autoproxy] - nginx reverse proxy image that auto-discovers and proxies for services in your CoreOS cluster
