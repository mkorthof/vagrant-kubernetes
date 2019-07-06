# vagrant-kubernetes

Vagrantfile to setup a Kubernetes cluster consisting of 1 master and 2 nodes as VMs on your local machine

---

### Updated version:

- Forked from original: https://github.com/grahamdaley/vagrant-kubernetes
- Supports Kubernetes: **1.15** (includes option to change version)
- Addons/plugins: network weave|flannel|calico|canal, dashboard, metrics, nginx
- Support multiple concurrent versions using kubevb.bat

### Documentation:

Added documentation for the updated version can be found below:

- [Multiple versions](#Multiple-versions)
- [Dashboard](#Dashboard)
- [Changes](#Changes)
- [Todo](#Todo)

And comments inside [Vagrantfile](Vagrantfile)

---

### Original README:

#### Kubernetes:

> _Kubernetes (commonly referred to as "k8s") is an open source container cluster manager originally designed by Google and
> donated to the Cloud Native Computing Foundation. It aims to provide a platform for automating deployment, scaling, and
> operations of application containers across clusters of hosts. It usually works with the Docker container tool and
> coordinates between a wide cluster of hosts running Docker_ – [from Wikipedia](https://en.wikipedia.org/wiki/Kubernetes).

#### Minikube:

Kubernetes includes a command line tool, Minikube, which is a tool that makes it easy to run Kubernetes locally. Minikube runs a single-node Kubernetes 'cluster' inside a VM on your local computer. It is focused on users looking to try out Kubernetes or develop with it day-to-day. While Minikube is easy to use and will help you get going quickly, it is restricted to just one node, and so won't allow you to really test your application in a multi-node environment.

#### Vagrant:

This Vagrant script carries out all of the major steps required to setup a Kubernetes cluster on your local machine, running Ubuntu Linux, using the free VirtualBox application. This cluster may be setup on any Mac or Windows PC supported by VirtualBox and Vagrant.

This cluster enables application containers to be tested in a multi-node environment, to see how well they respond to the challenges of scaling. It can also help identify any issues related to concurrency, even while in the development environment, so they can be resolved as early as possible in the development process.

The cluster consists of Kubernetes 3 hosts:

- one Kubernetes Master
- two Kubernetes Nodes

## Download

* __[VirtualBox](https://www.virtualbox.org/)__ 
  - Install this to run virtual machines on your local Mac or Windows PC.

* __[Vagrant](https://www.vagrantup.com/)__ 
  - Install this to allow quick and easy setup of the virtual machines we will be using in this article.

* __[kubectl](https://kubernetes.io/docs/user-guide/prereqs/)__ 
  - Install this on your local Mac/PC, to allow you to control your cluster and access the Kubernetes dashboard through a web browser.

## Configuring and Running the Virtual Machines

1. Download the [Vagrantfile](https://raw.githubusercontent.com/mkorthof/vagrant-kubernetes/master/Vagrantfile) and save it in a new, empty folder on your Mac or Windows PC.

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
  * Mac: `$ export KUBECONFIG="$KUBECONFIG:`pwd`/admin.conf"`
  * Windows: `SET "KUBECONFIG=%KUBECONFIG%;%CD%\admin.conf"`

4. Optionally, proxy the admin console to your local Mac/Windows PC
  * `$ kubectl proxy`

You can also use `--kubeconfig` instead of the "KUBECONFIG" env var:
```
C:\vagrant-kubernetes\kubectl --kubeconfig admin.conf proxy
```

Leaving the above command running, access the [Kubernetes Admin Console](http://localhost:8001/ui) in your web browser. This requires setting `$K8S_DASHBOARD = 1` in Vagrantfile first, before running `vagrant up`.

You should now have a fully working Kubernetes cluster running on your local machine, on to which you can deploy containers using either the admin console or the kubectl command line tool.

---

## Multiple versions

Use multiple concurrent k8s versions.

``` bash
This wrapper will chdir to "k8s-version" subdir first before
running Vagrant, allowing multiple Kubernetes versions to co-exist.

SYNTAX:  ".\kubevg.bat [--help|--version] | [--create] <k8s-version> [vagrant|kubectl <command>]"

         [--create] <k8s-version>] create new version subdir and run "vagrant up"
         [--help] show these help instructions
         [--version] list available Kubernetes Ubuntu package versions

VAGRANT: ".\kubevg.bat <k8s-version> vagrant <commmand>"
KUBECTL: ".\kubevg.bat <k8s-version> kubectl <commmand>"

EXAMPLE: ".\kubevg.bat --create 1.13.0"
         ".\kubevg.bat 1.13.0 vagrant ssh host0"
         ".\kubevg.bat 1.13.0 kubectl proxy"
```

## Dashboard

If you enable the Dashboard in the Vagrantfile by setting `$K8S_DASHBOARD = 1`.
Two files will be created:

- "dashboard-token.txt" containing a bearer token to login
- "dashboard.html" which auto redirects to the Dashboard URL

You probably want to start `kubectl proxy` first, combined with `kubevg.bat` when using multiple versions (see above).

## Changes

- [2019-06-23] v1.15 removed canal, updated addon deployments, improved kubevg
- [2019-05-23] added support for multiple concurrent k8s versions, multimaster prep, ingress
- [2019-04-20] v1.14 updates, ubuntu/bionic box, runtime options
- [2019-01-25] fixed busybox deploy, added vg_box and dist os options
- [2018-12-04] v1.13 fixes/workarounds
- [2018-11-10] v1.12 fixes/workarounds, hostfile, addon options

## TODO

- check if vb natproxy fix is still needed
- fix return from sleep vbox by removing/readding NAT network:
  - `VBoxManage controlvm "1234_host0_12345" nic1 null`
  - `VBoxManage controlvm "1234_host0_12345" nic1 nat`
- add metallb/nginx as default lb/ingress and add hello-world example
- finish multi master support
