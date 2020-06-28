# vagrant-kubernetes

Vagrantfile to setup a Kubernetes cluster consisting of 1 master and 2 nodes as VM's running on your local machine

---

## Updated version

- Forked from original: <https://github.com/grahamdaley/vagrant-kubernetes>
- Supports Kubernetes: **1.18+** (includes option to change version)
- Addons/plugins: network weave|flannel|calico|canal, dashboard, metrics, nginx, metallb
- Supports multiple versions using 'kubevg.bat'

## Documentation

Added for the updated version:

- [Multiple versions](README.md#Multiple-versions)
- [Dashboard](README.md#Dashboard)
- [CHANGES.md](CHANGES.md)
- Comments inside [Vagrantfile](Vagrantfile)

---

### Original README

#### Kubernetes

> _Kubernetes (commonly referred to as "k8s") is an open source container cluster manager originally designed by Google and donated to the Cloud Native Computing Foundation. It aims to provide a platform for automating deployment, scaling, and operations of application containers across clusters of hosts. It usually works with the Docker container tool and coordinates between a wide cluster of hosts running Docker_
 – [from Wikipedia](https://en.wikipedia.org/wiki/Kubernetes).

#### Minikube

Kubernetes includes a command line tool, Minikube, which is a tool that makes it easy to run Kubernetes locally. Minikube runs a single-node Kubernetes 'cluster' inside a VM on your local computer. It is focused on users looking to try out Kubernetes or develop with it day-to-day. While Minikube is easy to use and will help you get going quickly, it is restricted to just one node, and so won't allow you to really test your application in a multi-node environment.

#### Vagrant

This Vagrant script carries out all of the major steps required to setup a Kubernetes cluster on your local machine, running Ubuntu Linux, using the free VirtualBox application. This cluster may be setup on any Mac or Windows PC supported by VirtualBox and Vagrant.

This cluster enables application containers to be tested in a multi-node environment, to see how well they respond to the challenges of scaling. It can also help identify any issues related to concurrency, even while in the development environment, so they can be resolved as early as possible in the development process.

The cluster consists of Kubernetes 3 hosts:

- one Kubernetes Master
- two Kubernetes Nodes

## Download

- __[VirtualBox](https://www.virtualbox.org/)__
  - Install this to run virtual machines on your local Mac or Windows PC.

- __[Vagrant](https://www.vagrantup.com/)__
  - Install this to allow quick and easy setup of the virtual machines we will be using in this article.

- __[kubectl](https://kubernetes.io/docs/user-guide/prereqs/)__
  - Install this on your local Mac/PC, to allow you to control your cluster and access the Kubernetes dashboard through a web browser.

On Windows you can use [Chocolatey](https://chocolatey.org): `choco install virtualbox vagrant kubernetes-cli`

## Configuring and Running the Virtual Machines

1. Download the [Vagrantfile](https://raw.githubusercontent.com/mkorthof/vagrant-kubernetes/master/Vagrantfile) and save it in a new, empty folder on your Mac or Windows PC.

2. Start up the VMs in one go

   `$ vagrant up`

    You will then see a number of messages, starting with:

    ``` sh
      Bringing machine 'master' up with 'virtualbox' provider...
      Bringing machine 'node1' up with 'virtualbox' provider...
      Bringing machine 'node2' up with 'virtualbox' provider...
    ```

    as Vagrant downloads the 'box' image (the image of the basic VM we will be using) and sets up each of the 3 VM instances.

    Once the box image has been downloaded, numerous additional packages will be downloaded and installed automatically, including those required for Docker and Kubernetes. This process will take approximately 15 minutes to complete.

3. Get the configuration for our new Kubernetes cluster so we can access it directly from our local machine

    - Mac: `$ export KUBECONFIG="$KUBECONFIG:$(pwd)/admin.conf"`
    - Windows: `SET "KUBECONFIG=%KUBECONFIG%;%CD%\admin.conf"`

4. Optionally, proxy the admin console to your local Mac/Windows PC

    - `$ kubectl proxy`

You can also use `--kubeconfig` instead of the "KUBECONFIG" env var:

``` batch
C:\vagrant-kubernetes\kubectl --kubeconfig admin.conf proxy
```

Leaving the above command running, access the [Kubernetes Admin Console](http://localhost:8001/ui) in your web browser.

You should now have a fully working Kubernetes cluster running on your local machine, on to which you can deploy containers using either the admin console or the kubectl command line tool.

---

Note that all VM's will have names prefixed by ***kubevg-*** for example: 'kubevg-host0'.

In case of network issues in Kubernetes:

- have a look at 'Network IP ranges (RFC 1918)' in the Vagrantfile
- try changing to the default prefixes for pods and pool
- if you have network overlap try using an other block
- If you're still having issues test if changing network addons helps (e.g. Flannel instead of Calico)

## Multiple versions

Multiple k8s versions can co-exist by using 'kubevg.bat'. All versions will use the same Vagrantfile.

This can be useful if you want to test deployments in different k8s versions for example.

You could even try running concurrent clusters. This would require `$IP_RANDOM = 1` to be set in the Vagrantfile so it uses different ip ranges for the VM's (untested). The ip prefix will be written to `.ip_prefix` in each k8s version subdir.

Run `kubevg.bat -h` for details:

``` batch

-------------------------------------------------------------------------------
[kubevg]                 (Kube)rnetes (V)a(g)rant wrapper
-------------------------------------------------------------------------------

  This wrapper will change dir to "k8s-version" subdir first before running
  running Vagrant or kubectl, thus allowing multiple Kubernetes version
  to co-exist (using the same Vagrantfile).

SYNTAX:  ".\kubevg.bat [--help|--version|--list|--clip|--proxy] <k8s-version>
         ".\kubevg.bat [--create|--recreate|--reinstall] <k8s-version>"

OPTIONS: --help show these help instructions
         --list show available Kubernetes version subdirs
         --version show available Kubernetes Ubuntu package versions
         --create <k8s-version> create new version subdir, runs "vagrant up"
         --recreate <k8s-version> re-create using "vagrant destroy" then "up"
         --reinstall <k8s-version> remove version subdir first, then recreate
         --clip <k8s-version> copy K8s Dashboard token to clipboard
         --proxy <k8s-version> start proxy and K8s Dashboard

WRAPPER SYNTAX: ".\kubevg.bat <k8s-version> [vagrant|kubectl <command>]"
     > VAGRANT: ".\kubevg.bat <k8s-version> vagrant <help|commmand>"
     > KUBECTL: ".\kubevg.bat <k8s-version> kubectl <help|commmand>"

EXAMPLES: ".\kubevg.bat --create 1.13.0"
          ".\kubevg.bat 1.13.0 vagrant ssh kubevg-host0"
          ".\kubevg.bat 1.13.0 kubectl get nodes"

```

## Dashboard

Enable the Kubernetes Dashboard in the Vagrantfile by setting `$K8S_DASHBOARD = 1`.

Two files will be created:

- "dashboard-token.txt" containing a bearer token to login
- "Dashboard.html" which auto redirects to the Dashboard URL

Run `kubevg.bat --proxy 1.2.3` to start kubectl, copy token to clipboard automatically, and open the Dashboard in your default browser.

Or, manually start `kubectl.exe proxy`

- When using multiple versions instead use: `kubevg.bat 1.2.3 kubectl proxy`
- Copy the token to clipboard using `kubevg.bat --clip 1.2.3` or from 'dashboard-token.txt'
- Open 'Dashboard.html' in your browser

## Changes

See [CHANGES.md](CHANGES.md)
