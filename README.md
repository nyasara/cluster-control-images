This is a set of Docker containers designed to be used to run a Microsoft Azure CoreOS cluster.  Each is set up on the Docker registry as an automated build.

The images include

* synchronizer - Automatically pulls your custom application packages from git repos or Azure blob storage and ensures they are propagated throughout the cluster as needed
* etcdwatcher - Manages lists of keys from files in your packages and ensures they are loaded into etcd
* autoproxy - nginx reverse proxy that runs on every machine in the cluster to provide reliable access between services
* registry - Azure-backed Docker registry to hold your custom containers once built
* librarian - Automatically builds your custom containers and puts them in the registry
* foreman - Reads deployment information, including custom auto-scaling scripts, and manages deployments through fleet
* logwatcher - Runs on every machine in the cluster, grabs logs from your applications, and stores them in Azure blob storage

This is still a work in progress, most of these are not done yet.  See individual READMEs for progress and instructions on customizing/deploying
