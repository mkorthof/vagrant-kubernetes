# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'securerandom'

#
# Install local Kubernetes cluster
#
# - K8s nodes: 1 master and 2 workers, hostnames: host[0-2]
# - Boxes: VirtualBox VM's, 2GB, Ubuntu
#
# Usage:  - git clone <repo>
#         - vagrant up
#         - vagrant ssh host0, run kubectl etc
#         - shared dir gets mounted as /vagrant (for token file, admin.conf)
#
# - Original source: https://github.com/grahamdaley/vagrant-kubernetes (v1.6?)
# - Updated version: https://github.com/mkorthof/vagrant-kubernetes (v1.13)
#
# Changes: 
#		[2019-04-20] v1.14 updates, ubuntu/bionic box, runtime options
#		[2019-01-25] fixed busybox deploy, added vg_box and dist os options
#		[2018-12-04] v1.13 fixes/workarounds
#		[2018-11-10] v1.12 fixes/workarounds, hostfile, addon options
#
# TODO:
# - support multiple concurrent versions
# - multi master support
#						

$VG_BOX	=	"ubuntu/bionic64"			# vagrant box
$NR_NODES = 2                   # number of worker nodes
$TOKEN_FILE = ".cluster_token"  # token for kubeadm init
$IP_PREFIX = "192.168.33"       # [ip] vm's/nodes get <prefix>.{10+i}
$K8S_OS_DIST = "xenial"					# kubernetes os dist (apt packages)
$K8S_VERSION = "1.14.0-00"      # kubernetes version (apt packages)
$K8S_RUNTIME = "docker-ce"			# [docker.io|docker-ce] container runntime
$DOCKER_VERSION = "18.06.2~ce~3-0~ubuntu"
$K8S_NETWORKING = "calico"      # [weave|flannel|calico|canal] network
$K8S_NETWORKING_RBAC = 0				# [0/1]
$K8S_COREDNS = 1                # [0/1] ( ignore: default since 1.11 )
$K8S_DASHBOARD = 0              # [0/1] dashboard
$K8S_METRICS_SERVER = 0         # [0/1] metics-server
$K8S_NGINX = 0                  # [0/1] nginx ingress
$K8S_BUSYBOX = 1                # [0/1] busybox example pod in default namespace

# Enable this fix if you're having issues with metrics-server
$K8S_METRICS_SVR_FIX = 0        # [0/1] add insecure-tls and internalips args

# Normally these are not needed, seems only weave might need them
$K8S_KPOXY_FIX = 0              # [0/1] fix kube-proxy
$K8S_KPOXY_FIX_LEGACY = 0       # [0/1] ( safe to ignore )
$K8S_API_SROUTE = 0             # [0/1] static route api

$K8S_ADMIN_CONF = "/etc/kubernetes/admin.conf"

$K8S_DASH_TOKEN = "/vagrant/dashboard-token.txt"

# Enable if you're having VirtualBox DNS issues
$VB_DNSPROXY_NAT = 1            # [0/1] enable nat dns proxy in vbox

### END OF CONFIG ###

$K8S_DEBUG = 0

if not ENV['K8S_VERSION'].nil?
	$K8S_VERSION=ENV['K8S_VERSION']
end
if ($K8S_DEBUG == 1) then
	$K8S_VERSION = "0.0-0"
end

# same as 'kubeadm token generate'
def get_cluster_token()
  if File.exist?($TOKEN_FILE) then
    token = File.read($TOKEN_FILE)
  else
    token = "#{SecureRandom.hex(3)}.#{SecureRandom.hex(8)}"
    File.write($TOKEN_FILE, token)
  end
  token
end

def common_setup_script()
  script = <<SCRIPT
if [ #{$K8S_DEBUG} -eq 1 ]; then
	echo "DEBUG: common_setup_script K8S_RUNTIME=#{$K8S_RUNTIME} DOCKER_VERSION={$DOCKER_VERSION}"
  echo "DEBUG: common_setup_script K8S_OS_DIST=#{$K8S_OS_DIST} K8S_VERSION=#{$K8S_VERSION}"; exit
fi
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export DEBIAN_FRONTEND=noninteractive
locale-gen en_US.UTF-8 || dpkg-reconfigure locales
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF1 > /etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-#{$K8S_OS_DIST} main
EOF1
apt-get update
apt-get install -y ntp
systemctl enable ntp
systemctl start ntp
if [ #{$K8S_RUNTIME} = "docker.io" ]; then
	apt-get install -y docker.io
	cat <<EOF2 > /etc/docker/daemon.json
{
  "insecure-registries": ["#{$IP_PREFIX}.1:5000"]
  "exec-opts": ["native.cgroupdriver=systemd"],
}
EOF2
	systemctl enable docker && systemctl start docker
elif [ #{$K8S_RUNTIME} = "docker-ce" ]; then
	apt-get update && apt-get install -y apt-transport-https ca-certificates curl software-properties-common
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
	add-apt-repository \
	  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
	  $(lsb_release -cs) \
	  stable"
	apt-get update && apt-get install -y docker-ce=#{$DOCKER_VERSION}
	cat <<EOF3 > /etc/docker/daemon.json
{
  "insecure-registries": ["#{$IP_PREFIX}.1:5000"],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF3
	mkdir -p /etc/systemd/system/docker.service.d
	systemctl daemon-reload
	systemctl restart docker
fi
if { curl -s https://packages.cloud.google.com/apt/dists/kubernetes-#{$K8S_OS_DIST}/main/binary-amd64/Packages | awk /Version/'{print $2}'; } | \
	grep -q "^#{$K8S_VERSION}"
then
	v="#{$K8S_VERSION}"
	if ! echo "#{$K8S_VERSION}" | grep -Eq -- "\-00$"; then
		v="${v}-00"
	fi
	apt-get install -y kubelet=${v} kubeadm=${v} kubectl=${v} kubernetes-cni
else 
	echo "ERROR: #{$K8S_VERSION} is incorrect"
	exit 1
fi
systemctl enable kubelet && systemctl start kubelet
unset DEBIAN_FRONTEND
SCRIPT
end

def master_setup_script(cluster_token)
  script = <<SCRIPT
if [ #{$K8S_DEBUG} -eq 1 ]; then
  echo "DEBUG: master_setup_script NODES=#{$NODES}"; exit
fi
##curl -s -O http://stedolan.github.io/jq/download/linux64/jq && chmod +x ./jq && mv jq /usr/local/bin
export DEBIAN_FRONTEND=noninteractive
apt-get install -y jq
sed 's/127.0.[0-1].1.*host0/#{ip_from_num(0)}\thost0\thost0/' -i /etc/hosts
for i in $(seq 1 #{$NR_NODES}); do
	# replace ip<tab>host
	if ! grep -q host${i} /etc/hosts; then
		printf "%s\t%s\n" \
		"$(echo #{ip_from_num(0)}|sed -r "s/\.[0-9]{2} ?$/.$((10+i))/")" \
		"host${i}" | tee -a /etc/hosts
	fi
done

# Setting apiserver-advertise-address makes sure we listen on the correct vm interface, not the NAT one
kadm_init_args+=" --apiserver-advertise-address=#{ip_from_num(0)}"

# Disabled: CoreDNS is the default since v1.11
# [ #{$K8S_COREDNS} = "1" ] && kadm_init_args+=" --feature-gates CoreDNS=true"

[ #{$K8S_NETWORKING} = "flannel" ] &&	kadm_init_args+=" --pod-network-cidr=10.244.0.0/16"
[ #{$K8S_NETWORKING} = "canal" ] &&	kadm_init_args+=" --pod-network-cidr=10.244.0.0/16"
[ #{$K8S_NETWORKING} = "calico" ] && kadm_init_args+=" --pod-network-cidr=192.168.0.0/16"

kubeadm init --token=#{cluster_token} $kadm_init_args && \
{ test -d /root/.kube || mkdir /root/.kube; } && \
{ test -s $K8S_ADMIN_CONF && cp #{$K8S_ADMIN_CONF} /root/.kube/config || \
	echo "ERROR: #{$K8S_ADMIN_CONF} is missing"; }

if [ #{$K8S_NETWORKING} = "flannel" ]; then
	kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
elif [ #{$K8S_NETWORKING} = "calico" ]; then
	kubectl apply -f https://docs.projectcalico.org/v3.6/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml
	if [ #{$K8S_NETWORKING_RBAC} ]; then
 		kubectl apply -f https://docs.projectcalico.org/master/manifests/rbac-kdd-calico.yaml
	fi
elif [ #{$K8S_NETWORKING} = "canal" ]; then
	kubectl apply -f https://docs.projectcalico.org/v3.6/getting-started/kubernetes/installation/hosted/canal/canal.yaml
	if [ #{$K8S_NETWORKING_RBAC} ]; then
		kubectl apply -f https://docs.projectcalico.org/v3.6/manifests/rbac-kdd-flannel.yaml
	fi
elif [ #{$K8S_NETWORKING} = "weave" ]; then
	### Fix for kube-proxy, k8s version 1.[4-6]
	if [ #{$K8S_KPOXY_FIX_LEGACY} ]; then
	 kubectl -n kube-system get ds/kube-proxy -o json \
	  | jq '.items[0].spec.template.spec.containers[0].command |= .+ ["--proxy-mode=userspace"]' \
	  | kubectl apply -f - && kubectl -n kube-system delete pods -l 'component=kube-proxy'
	fi
	### Fix for kube-proxy, k8s version 1.12
	if [ #{$K8S_KPOXY_FIX} ]; then
		kubectl -n kube-system get ds -l 'k8s-app=kube-proxy' -o json \
		 | jq '.items[0].spec.template.spec.containers[0].command |= .+ ["--proxy-mode=userspace"]' \
		 | jq '.items[0].spec.template.spec.containers[0].command |= .+ ["--cluster-cidr=10.32.0.0/12"]' \
		 | kubectl apply -f - && kubectl -n kube-system delete pods -l 'k8s-app=kube-proxy'
	fi
	### Alternative method, add static route if api on clusterip 10.96.0.1 can't be reached from workers
	if [ #{$K8S_API_SROUTE} ]; then
		ip route add 10.96.0.1 via 192.168.33.10
	fi
	kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
fi
if [ #{$K8S_NGINX} = "1" ]; then
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/mandatory.yaml
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/provider/baremetal/service-nodeport.yaml
	#https://raw.githubusercontent.com/kubernetes/contrib/master/ingress/controllers/nginx/examples/default-backend.yaml
fi
if [ #{$K8S_DASHBOARD} = "1" ]; then
	kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/kubernetes-dashboard.yaml
	kubectl -n kube-system describe secrets kubernetes-dashboard | grep token: > #{$K8S_DASH_TOKEN}
fi
if [ #{$K8S_METRICS_SERVER} = "1" ]; then
  for f in aggregated-metrics-reader auth-delegator auth-reader metrics-apiservice \
           metrics-server-deployment metrics-server-service resource-reader; do
    if [ #{$K8S_METRICS_SVR_FIX} = "1" ]; then
      if [ "$f" = "metrics-server-deployment" ]; then
        cmd="command: [ \"\/metrics-server\" ]"
        args="args: [ \"--kubelet-insecure-tls\", \"--kubelet-preferred-address-types=InternalIP\" ]"
        sp="\n        "
        curl -s -o - https://raw.githubusercontent.com/kubernetes-incubator/metrics-server/master/deploy/1.8%2B/${f}.yaml | \
        sed '/^\s*containers:/,/\s*imagePullPolicy/{N;s/\(imagePullPolicy: Always\)$/\1'"${sp}${cmd}${sp}${args}"'/}' | \
        kubectl apply -f -
      fi
    fi  
    kubectl create -f https://raw.githubusercontent.com/kubernetes-incubator/metrics-server/master/deploy/1.8%2B/${f}.yaml
  done
fi
if [ #{$K8S_BUSYBOX} = "1" ]; then
  echo "Creating busybox pod example..."
	# Added 30 sec sleep because 'default' namespace might not exist yet
  { sleep 30 && kubectl create -f https://k8s.io/examples/admin/dns/busybox.yaml; } &
fi
[ -s #{$K8S_ADMIN_CONF} ] && { cp #{$K8S_ADMIN_CONF} /vagrant || echo "ERROR: #{$K8S_ADMIN_CONF} is missing"; }
SCRIPT
# puts "Dashboard:"
# puts "first start: 'kubectl proxy --kubeconfig admin.conf', then goto"
# puts "http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/"
end

def node_setup_script(host_no, cluster_token)
  script = <<SCRIPT
sed 's/127.0.[0-1].1.*host#{host_no}/#{ip_from_num(host_no)}\thost#{host_no}\thost#{host_no}/' -i /etc/hosts
for i in $(seq 0 #{$NR_NODES}); do
	# add ip and host to hosts file
	if ! grep -q host${i} /etc/hosts; then
		printf "%s\t%s\n" \
		"$(echo #{ip_from_num(0)}|sed -r "s/\.[0-9]{2} ?$/.$((10+i))/")" \
		"host${i}" | tee -a /etc/hosts
	fi
done
kubeadm join #{ip_from_num(0)}:6443 --token=#{cluster_token} --discovery-token-unsafe-skip-ca-verification || \
kubeadm join --discovery-file /vagrant/admin.conf
SCRIPT
end

def ip_from_num(i)
  "#{$IP_PREFIX}.#{10+i}"
end

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  config.vm.box = $VG_BOX
  config.vm.box_check_update = true

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  config.vm.provider "virtualbox" do |vb|
    # Display the VirtualBox GUI when booting the machine
    vb.gui = false
    # Customize the amount of memory on the VM:
    vb.memory = "2048"
		
		# https://www.virtualbox.org/manual/ch09.html#nat_host_resolver_proxy
		if $VB_DNSPROXY_NAT == 1 then
			vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
		end
  end

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
  config.vm.provision "shell", inline: common_setup_script()

  # Generate a token to authenticate hosts joining the cluster
  cluster_token = get_cluster_token()

  # Kubernetes hosts (host 0 is master)
  (0..$NR_NODES).each do |i|
    config.vm.define "host#{i}" do |host|
      host.vm.network "forwarded_port", guest: 8001, host: (8001 + i)
      host.vm.network "private_network", ip: ip_from_num(i)
      host.vm.hostname = "host#{i}"

      if (i == 0) then
        host.vm.provision "shell", inline: master_setup_script(cluster_token)
      else
				host.vm.provision "shell", inline: node_setup_script(i, cluster_token)
      end
    end
  end

end
