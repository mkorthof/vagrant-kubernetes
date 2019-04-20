# vagrant-kubernetes
Vagrantfile to setup a Kubernetes cluster consisting of 1 master and 2 nodes as VMs on your local machine

### Updated version:
- Forked from original: https://github.com/grahamdaley/vagrant-kubernetes
- Supports Kubernetes: **1.14** (includes option to change version)
- Addons/plugins: network weave|flannel|calico|canal, dashboard, metrics, nginx

> Kubernetes (commonly referred to as "k8s") is an open source container cluster manager originally designed by Google and 
> donated to the Cloud Native Computing Foundation. It aims to provide a platform for automating deployment, scaling, and 
> operations of application containers across clusters of hosts. It usually works with the Docker container tool and 
> coordinates between a wide cluster of hosts running Docker – [from Wikipedia](https://en.wikipedia.org/wiki/Kubernetes).

Kubernetes includes a command line tool, Minikube, which is a tool that makes it easy to run Kubernetes locally. Minikube runs a single-node Kubernetes 'cluster' inside a VM on your local computer. It is focused on users looking to try out Kubernetes or develop with it day-to-day. While Minikube is easy to use and will help you get going quickly, it is restricted to just one node, and so won't allow you to really test your application in a multi-node environment.

This Vagrant script carries out all of the major steps required to setup a Kubernetes cluster on your local machine, running Ubuntu Linux, using the free VirtualBox application. This cluster may be setup on any Mac or PC supported by VirtualBox and Vagrant.

This cluster enables application containers to be tested in a multi-node environment, to see how well they respond to the challenges of scaling. It can also help identify any issues related to concurrency, even while in the development environment, so they can be resolved as early as possible in the development process.

The cluster consists of Kubernetes 3 hosts:

- one Kubernetes Master
- two Kubernetes Nodes

## Download

* __[VirtualBox](https://www.virtualbox.org/)__ 
  - Install this to run virtual machines on your local Mac or PC.

* __[Vagrant](https://www.vagrantup.com/)__ 
  - Install this to allow quick and easy setup of the virtual machines we will be using in this article.

* __[kubectl](https://kubernetes.io/docs/user-guide/prereqs/)__ 
  - Install this on your local Mac/PC, to allow you to control your cluster and access the Kubernetes dashboard through a web browser.

## Configuring and Running the Virtual Machines

1. Download the [Vagrantfile](https://raw.githubusercontent.com/mkorthof/vagrant-kubernetes/master/Vagrantfile) and save it in a new, empty folder on your Mac or PC.

2. Start up the VMs in one go
  ```sh
  $ vagrant up
  ```

  You will then see a number of messages, starting with:

  ```
  Bringing machine 'master' up with 'virtualbox' provider... 
  Bringing machine 'node1' up with 'virtualbox' provider... 
  Bringing machine 'node2' up with 'virtualbox' provider...
  ```

  as Vagrant downloads the 'box' image (the image of the basic VM we will be using) and sets up each of the 3 VM instances. 

  Once the box image has been downloaded, numerous additional packages will be downloaded and installed automatically, including those required for Docker and Kubernetes. This process will take approximately 15 minutes to complete.

3. Get the configuration for our new Kubernetes cluster so we can access it directly from our local machine
  ```
  $ export KUBECONFIG="$KUBECONFIG:`pwd`/admin.conf"
  ```

4. Optionally, proxy the admin console to your local Mac/PC
  ```
  $ kubectl proxy
  ```

Leaving the above command running, access the [Kubernetes Admin Console](http://localhost:8001/ui) in your web browser.

You should now have a fully working Kubernetes cluster running on your local machine, on to which you can deploy containers using either the admin console or the kubectl command line tool.

## Changes

- [2018-12-04] v1.13 fixes/workarounds
- [2018-11-10] v1.12 fixes/workarounds, hostfile, addon options

## Todo

- Support multiple concurrent versions
- Ingress/nginx
- Show/save Dashboard token
