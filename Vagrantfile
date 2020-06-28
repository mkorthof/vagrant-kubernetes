# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'securerandom'

# -----------------------------------------------------------------------------
# Install local Kubernetes cluster
# -----------------------------------------------------------------------------
#
# - K8s nodes: 1 master and 2 workers, hostnames: host[0-2]
# - Boxes: VirtualBox VM's, 2GB RAM, Ubuntu OS
#
# Usage:  1) git clone <repo>
#         2) vagrant up
#         3) vagrant ssh host0, run kubectl, ... etc
#         4) shared dir gets mounted as '/vagrant' (token file, admin.conf)
#         5) for multiple k8s versions use 'kubevg.bat'
#
# Changes: See CHANGES.md
#
# Original source: https://github.com/grahamdaley/vagrant-kubernetes (k8s v1.6?)
# Updated version: https://github.com/mkorthof/vagrant-kubernetes (k8s v1.18)
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
# Usually leaving these options as-is should be fine

# Vagrant options
# ###############

# - Where it says "node(s)" that means the VM(s) it runs on as well
# - Use *1* master node for now e.g. $MASTER_NODES = 1
# - Enable dns proxy if you're behind NAT and having DNS issues with VirtualBox

$VG_BOX	= "ubuntu/xenial64"					# vagrant box
$MASTER_NODES = 1							# nr of master node(s)
$WORKER_NODES = 2							# nr of worker node(s)
$TOKEN_FILE = ".cluster_token"				# token for kubeadm init
$IP_PREFIX = "192.168.33"					# set node ip(s) to <1.2.3>.{10+i}
$IP_RANDOM = 0								# [0/1] use random prefix in 192.168.33.0/17
$KUBEADM_INIT = "yaml"						# [flags|yaml] kubeadm init config method
$VB_FWD_PROXY = 1							# [0/1] forward proxy port (8001)
$VB_DNSPROXY_NAT = 0						# [0/1] enable nat dns proxy in vbox

# Kubernetes options
# ##################

# - Best leave OS_DIST at "xenial", even for newer Ubuntu dist versions like 20.04+
# - Docker support: https://kubernetes.io/docs/setup/production-environment/container-runtimes
# ( Removed options for older k8s versions: $K8S_KUBEPROXY_CFIX, $K8S_KUBEPROXY_UFIX )

$K8S_VERSION = "1.18.5"						# kubernetes version for apt packages
$K8S_OS_DIST = "xenial"						# kubernetes os dist for apt packages
$K8S_RUNTIME = "docker-ce"					# [docker.io|docker-ce] container runtime
$K8S_NODE_IP = 1							# [0/1] set kubelet node_ip to VM IPS
$K8S_API_STATIC_ROUTE = 0					# [0/1] set static route to cluster-api ip (weave)
$DOCKER_VERSION = "5:19.03.11~3-0~ubuntu-xenial"	# use verified version (k8s release notes)
$K8S_ADMIN_CONF = "/etc/kubernetes/admin.conf"		# leave as-is, will be copied to /vagrant

# Kubernetes Addons
# #################

$K8S_NETWORKING = "calico"					# [weave|flannel|calico] network addon
$K8S_NETWORKING_RBAC = 0					# [0/1] rbac authorization
$K8S_NETWORKING_CALICOCTL = 1				# [0/1] deploy calicoctl pod
$K8S_DASHBOARD = 1							# [0/1] kubernetes dashboard
$K8S_METRICS_SERVER = 0						# [0/1] metrics-server
$K8S_NGINX = 0								# [0/1] nginx ingress
$K8S_METALLB = 0							# [0/1] metallb loadbalacner
$K8S_DNSUTILS = 1							# [0/1] dnsutils example pod in default namespace
$K8S_BUSYBOX = 1							# [0/1] busybox example pod in default namespace
$K8S_HELLOWORLD = 1							# [0/1] hello-world example, needs ingress
$K8S_DASH_TOKEN = "dashboard-token.txt"		# file in /vagrant with dashboard token to login
$K8S_DASH_LINK = "Dashboard.html"			# file in /vagrant with link to dashboard

# Network IP ranges (RFC 1918)
# #############################

# - Available blocks: "192.168.0.0/16", "10.0.0.0/8" or "172.16.0.0/12"
# - Do *not* overlap physical and/or overlay networks
# - Cluster CIDR is controlled by network plugin with K8S_PODNET_CIDR_CALICO
# - IP Pool in CALICO_IPV4POOL_CIDR should fall within 'cluster-cidr'
# - https://www.projectcalico.org/calico-ipam-explained-and-enhanced/

$K8S_SERVICE_CIDR = "10.96.0.0/12"				# default k8s service cidr
$K8S_PODNET_CIDR_FLANEL = "10.96.0.0/12"		# default flannel pods cidr
$K8S_PODNET_CIDR_CALICO = "192.168.128.0/17"	# tested with physical network "192.168/24"
$CALICO_IPV4POOL_CIDR = "192.168.192.0/18"		# tested with physical network "192.168/24"
# $K8S_PODNET_CIDR_CALICO = "192.168.0.0/16"	# uncomment for default calico pods cidr
# $CALICO_IPV4POOL_CIDR = "192.168.0.0/18"		# uncomment for default calico pool cidr

# Or, uncomment settings below to prevent *any* overlap with "192.168.0.0/16"

# $K8S_PODNET_CIDR_FLANEL = "10.244.0.0/16"
# $K8S_PODNET_CIDR_CALICO = "172.16.0.0/12"
# $CALICO_IPV4POOL_CIDR = "172.	0.0/16"

# -----------------------------------------------------------------------------
# END OF CONFIG
# -----------------------------------------------------------------------------

$K8S_DEBUG = 0 # [1|255] Set 1 to enable, 255 dumps vars and exits provisioning script
$K8S_FAKEVER = 0

if not ENV['K8S_VERSION'].nil?
	$K8S_VERSION=ENV['K8S_VERSION']
	# kubevb.bat also handles this
	if not Dir.exist?('../' + $K8S_VERSION) then
		puts 'ERROR: Dir ' + $K8S_VERSION + ' does not exist'
		exit 1
	end
end

if ($K8S_DEBUG == 255 && $K8S_FAKEVER == 1) then
	$K8S_VERSION = "0.0-0"
end

# Debug Vagrant
# #############

# - SET VAGRANT_LOG=info
# - vagrant up --debug
# - vagrant up --debug 2>&1 | Tee-Object -FilePath ".\vagrant.log"

# -----------------------------------------------------------------------------
# COMMON SETUP METHOD
# -----------------------------------------------------------------------------

def common_setup_script()
	script = <<SCRIPT
if [ #{$K8S_DEBUG} -eq 255 ]; then
	echo "DEBUG: master_setup_script NODES=#{$NODES} IP_PREFIX=#{$IP_PREFIX}"
	echo "DEBUG: common_setup_script K8S_RUNTIME=#{$K8S_RUNTIME} DOCKER_VERSION=#{$DOCKER_VERSION}"
	echo "DEBUG: common_setup_script K8S_OS_DIST=#{$K8S_OS_DIST} K8S_VERSION=#{$K8S_VERSION}"
	exit 1
fi
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export DEBIAN_FRONTEND=noninteractive
locale-gen en_US.UTF-8 || dpkg-reconfigure locales
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<-EOF_01 > /etc/apt/sources.list.d/kubernetes.list
	deb http://apt.kubernetes.io/ kubernetes-#{$K8S_OS_DIST} main
EOF_01
apt-get update
apt-get install -y ntp
systemctl enable ntp
systemctl start ntp
if [ #{$K8S_RUNTIME} = "docker.io" ]; then
	apt-get install -y docker.io || { echo "ERROR: could not install docker package"; exit 1; }
	cat <<-EOF_02 > /etc/docker/daemon.json
	{
		  "insecure-registries": ["#{$IP_PREFIX}.1:5000"],
		  "exec-opts": ["native.cgroupdriver=systemd"]
	}
EOF_02
	systemctl enable docker && systemctl start docker
elif [ #{$K8S_RUNTIME} = "docker-ce" ]; then
	apt-get update && apt-get install -y apt-transport-https ca-certificates curl software-properties-common
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
	add-apt-repository \
		"deb [arch=amd64] https://download.docker.com/linux/ubuntu \
		$(lsb_release -cs) \
		stable"
		apt-get update && apt-get install -y docker-ce=#{$DOCKER_VERSION} || { echo "ERROR: could not install docker package"; exit 1; }
		cat <<-EOF_03 > /etc/docker/daemon.json
			{
			  "insecure-registries": ["#{$IP_PREFIX}.1:5000"],
			  "exec-opts": ["native.cgroupdriver=systemd"],
			  "log-driver": "json-file",
			  "log-opts": {
			    "max-size": "100m"
			  },
			  "storage-driver": "overlay2"
			}
EOF_03
	mkdir -p /etc/systemd/system/docker.service.d
	systemctl daemon-reload
	systemctl restart docker
fi

if { curl -s https://packages.cloud.google.com/apt/dists/kubernetes-#{$K8S_OS_DIST}/main/binary-amd64/Packages | awk /Version/'{print $2}'; } | \
	grep -q "^#{$K8S_VERSION}"
then
	v="#{$K8S_VERSION}"
	if ! echo "#{$K8S_VERSION}" | grep -Eq -- "\-0[0-2]$"; then
		v="${v}-00"
	fi
	apt-get install -y kubelet=${v} kubeadm=${v} kubectl=${v} kubernetes-cni || { echo "ERROR: could not install k8s packages"; exit 1; }
else 
	echo "ERROR: #{$K8S_VERSION} is incorrect"
	exit 1
fi
systemctl enable kubelet && systemctl start kubelet
unset DEBIAN_FRONTEND
SCRIPT
end

# -----------------------------------------------------------------------------
# MASTER NODE(S) METHOD
# -----------------------------------------------------------------------------

def master_setup_script(cluster_token)
  script = <<SCRIPT
if [ #{$K8S_DEBUG} -eq 255 ]; then
	echo "DEBUG: master_setup_script NODES=#{$NODES}"
	echo "DEBUG: common_setup_script K8S_SERVICE_CIDR=#{$K8S_SERVICE_CIDR}"
	echo "DEBUG: common_setup_script $K8S_PODNET_CIDR_FLANEL=#{$K8S_PODNET_CIDR_FLANEL}"
	echo "DEBUG: common_setup_script $K8S_PODNET_CIDR_CALICO=#{$K8S_PODNET_CIDR_CALICO}"
	echo "DEBUG: common_setup_script CALICO_IPV4POOL_CIDR=#{$CALICO_IPV4POOL_CIDR}"
	exit 1
fi

## Alternative option - use jq binary:
## curl -s -O http://stedolan.github.io/jq/download/linux64/jq && chmod +x ./jq && mv jq /usr/local/bin

export DEBIAN_FRONTEND=noninteractive
apt-get install -y jq
i=0; while [ "$i" -lt #{$NODES} ]; do
	sed 's/127.0.[0-1].1.*host'"${i}'"/'"#{ip_from_num(0)}'"\thost'"${i}'"\thost0/' -i /etc/hosts
	i=$((i+1))
done
for i in $(seq 1 #{$NODES}); do
	# add ip and host to hosts file
	if ! grep -q host${i} /etc/hosts; then
		printf "%s\t%s\n" \
		"$(echo #{ip_from_num(0)}|sed -r "s/\.[0-9]{2} ?$/.$((10+i))/")" \
		"host${i}" | tee -a /etc/hosts
	fi
done
cat <<-EOF_06 > /etc/sysctl.d/99-k8s.conf
	net.bridge.bridge-nf-call-iptables = 1
	net.ipv4.ip_forward = 1
EOF_06
sysctl -p

# KUBEADM INIT
# ============

# NOTES: - By setting '(apiserver) advertise address' we make sure
#          we're listening on the correct VM interface, not the NAT one
#		 - Using a workaround to set node-ip, since putting
#		   it in 'kubeletExtraArgs' in config.yaml doesnt work
# 		 - kubeadm config migrate --old-config old.yaml --new-config new.yaml
[ #{$K8S_NETWORKING} = "flannel" ] && K8S_PODNET_CIDR="#{$K8S_PODNET_CIDR_FLANNEL}"
[ #{$K8S_NETWORKING} = "calico" ]  && K8S_PODNET_CIDR="#{$K8S_PODNET_CIDR_CALICO}"

# Use config.yaml (instead of flags)
# EXAMPLES: - https://godoc.org/k8s.io/kubernetes/cmd/kubeadm/app/apis/kubeadm/v1beta2
#			- https://github.com/kubernetes/kubeadm/issues/1468
#           - https://github.com/Yolean/youkube/blob/master/kubeadm-init-config.yml

if [ #{$KUBEADM_INIT} = "yaml" ]; then
cat <<-EOF_07 > /vagrant/kubeadm-init-config.yaml
	apiVersion: kubeadm.k8s.io/v1beta2
	kind: InitConfiguration
	bootstrapTokens:
	- token: #{cluster_token}
	localAPIEndpoint:
	  advertiseAddress: #{ip_from_num(0)}
	#nodeRegistration:
	#  kubeletExtraArgs:
	#	node-ip: #{ip_from_num(0)}
	---
	apiVersion: kubeadm.k8s.io/v1beta2
	kind: ClusterConfiguration
	networking:
	  podSubnet: $K8S_PODNET_CIDR
	  serviceSubnet: #{$K8S_SERVICE_CIDR}
	#---
	#apiVersion: kubelet.config.k8s.io/v1beta1
	#kind: KubeletConfiguration
	# kube-proxy specific options here
	#---
	#apiVersion: kubeproxy.config.k8s.io/v1alpha1
	#kind: KubeProxyConfiguration
	# kubelet specific options here
	#---
EOF_07
	if [ #{$K8S_METALLB} = "1" ]; then
	cat <<-EOF_08 >> /vagrant/kubeadm-init-config.yaml
		---
		apiVersion: kubeproxy.config.k8s.io/v1alpha1
		kind: KubeProxyConfiguration
		mode: "ipvs"
		ipvs:
		  strictARP: true
EOF_08
	fi
	kubeadm_init_args="--config /vagrant/kubeadm-init-config.yaml"
### Use flags ####
elif [ #{$KUBEADM_INIT} = "flags" ]; then
	kubeadm_init_args+=" --token=#{cluster_token}"
	kubeadm_init_args+=" --apiserver-advertise-address=#{ip_from_num(0)} "
	if [ #{$K8S_NETWORKING} = "flannel" ]; then
		kubeadm_init_args+=" --pod-network-cidr=#{$K8S_PODNET_CIDR}"
	elif [ #{$K8S_NETWORKING} = "calico" ]; then
		kubeadm_init_args+=" --service-cidr#{$K8S_SERVICE_CIDR}="
		kubeadm_init_args+=" --pod-network-cidr=#{$K8S_PODNET_CIDR}"
	fi
fi

if [ #{$K8S_DEBUG} -eq 1 ]; then
	echo "-------------------------------------------------------------------------------"
	echo kubeadm init ${kubeadm_init_args}
	echo "-------------------------------------------------------------------------------"
fi

kubeadm init ${kubeadm_init_args} && { \
	if [ -s "#{$K8S_ADMIN_CONF}" ]; then
		for i in /root /home/vagrant; do
			if [ ! -d "${i}/.kube" ]; then
				mkdir "${i}/.kube" && \
				chown --reference="${i}" "${i}/.kube"
			fi
			if [ ! -s "${i}/.kube/config" ]; then
				cp "#{$K8S_ADMIN_CONF}" "${i}/.kube/config" && \
				chown -R --reference="${i}" "${i}/.kube"
			else 
				echo "WARNING: ${i}/.kube/config already exists, not overwriting"
			fi
		done
		cp "#{$K8S_ADMIN_CONF}" /vagrant || echo "ERROR: could not copy #{$K8S_ADMIN_CONF} to /vagrant";
	else
		echo "ERROR: #{$K8S_ADMIN_CONF} is missing"
	fi
 } || { echo "ERROR: kubeadm init failed"; exit 1; }

# Set KUBELET_EXTRA_ARGS to '--node-ip'
# EXAMPLES: - https://v1-13.docs.kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/#using-internal-ips-in-your-cluster
#           - https://capstonec.com/help-i-need-to-change-the-pod-cidr-in-my-kubernetes-cluster/
#	        - https://github.com/kubernetes/kubernetes/blob/master/build/rpms/10-kubeadm.conf
#	        - https://www.linbit.com/en/linstor-csi-plugin-for-kubernetes/
if [ #{$K8S_NODE_IP} -eq 1 ]; then
	if [ -s "/etc/default/kubelet" ]; then
		sed -E 's/(KUBELET_EXTRA_ARGS=.*)/\1 --node-ip='"#{ip_from_num(0)}"'/' /etc/default/kubelet
	else
		echo "KUBELET_EXTRA_ARGS=--node-ip=#{ip_from_num(0)}" > /etc/default/kubelet
	fi && systemctl restart kubelet
	##Different method (not preffered) to do this:
	##sed -E -i 's/(KUBELET_EXTRA_ARGS=".*"")/\1 --node-ip='"#{ip_from_num(0)}"'/' /var/lib/kubelet/kubeadm-flags.env
fi

# NETWORKING
# ==========

### WEAVE ####
if [ #{$K8S_NETWORKING} = "weave" ]; then
	### OLD: Fix for kube-proxy, k8s version 1.[4-6] - proxy-mode=userspace
	if [ #{$K8S_KUBEPROXY_UFIX} ]; then
		kubectl -n kube-system get ds/kube-proxy -o json \
		  | jq '.items[0].spec.template.spec.containers[0].command |= .+ ["--proxy-mode=userspace"]' \
		  | kubectl apply -f - && kubectl -n kube-system delete pods -l 'component=kube-proxy'
	fi
	###  OLD: Fix for kube-proxy, k8s version 1.12 - cluster-cidr=10.32.0.0/12
	if [ #{$K8S_KUBEPROXY_CFIX} ]; then
		kubectl -n kube-system get ds -l 'k8s-app=kube-proxy' -o json \
		  | jq '.items[0].spec.template.spec.containers[0].command |= .+ ["--proxy-mode=userspace"]' \
		  | jq '.items[0].spec.template.spec.containers[0].command |= .+ ["--cluster-cidr=10.32.0.0/12"]' \
		  | kubectl apply -f - && kubectl -n kube-system delete pods -l 'k8s-app=kube-proxy'
	fi
	### Alternative method, add static route if api on clusterip(10.96.0.1) can't be reached from workers
	if [ #{$K8S_API_STATIC_ROUTE} ]; then
        ip route add 10.96.0.1 via #{$IP_PREFIX}.10
	fi
    kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
### CALICO ###
elif [ #{$K8S_NETWORKING} = "calico" ]; then
    ##
	## OLD: sed -E 's|value: \\"192.168.0.0\/16\\"|value: '"\\"#{$CALICO_IPV4POOL_CIDR}\\""'|' DISABLED_PIPE
	##
	curl -s https://docs.projectcalico.org/master/manifests/calico.yaml | \
		sed -E '/- name: CALICO_IPV4POOL_CIDR/,/value: /{s|\(value: \).*|\\1'"\\"#{$CALICO_IPV4POOL_CIDR}\\""'|}' | \
		kubectl apply -f -
	if [ #{$K8S_NETWORKING_CALICOCTL} = 1 ]; then
		kubectl apply -f https://docs.projectcalico.org/master/manifests/calicoctl.yaml
		echo 'alias calicoctl="kubectl exec -i -n kube-system calicoctl /calicoctl -- "' >> ~/.bash_aliases
		## Alternatives methods to use calicoctl:
		## bin  : curl -O -L https://github.com/projectcalico/calicoctl/releases/latest/download/calicoctl
		## etcd : kubectl apply -f https://docs.projectcalico.org/master/manifests/calicoctl-etcd.yaml
		## manifests(w/alias) : calicoctl create -f - < my_manifest.yaml
	fi
	if [ #{$K8S_NETWORKING_RBAC} ]; then
		kubectl apply -f https://docs.projectcalico.org/master/manifests/rbac/rbac-kdd-calico.yaml
	fi
### FLANNEL ###
elif [ #{$K8S_NETWORKING} = "flannel" ]; then
	kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
fi

# INGRESS CONTROLLER
# ==================

if [ #{$K8S_NGINX} = "1" ]; then
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/baremetal/deploy.yaml
fi

# MetalLB  https://metallb.universe.tf/
# Example: http://192.168.33.1[0-9]:3[0-9][0-9][0-9][0-9]/{testpath}
# Details: https://kubernetes.io/docs/concepts/services-networking/ingress/#the-ingress-resource

if [ #{$K8S_METALLB} = "1" ]; then
	kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/manifests/namespace.yaml
	kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/manifests/metallb.yaml
	kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
	kubectl apply -f - <<-'EOF_04'
		apiVersion: v1
		kind: ConfigMap
		metadata:
		  namespace: metallb-system
		  name: config
		data:
		  config: |
		    address-pools:
		    - name: default
		      protocol: layer2
		      addresses:
		      - #{$IP_PREFIX}.11-#{$IP_PREFIX}.12
		---
		apiVersion: networking.k8s.io/v1beta1
		kind: Ingress
		metadata:
		  name: test-ingress-1
		  annotations:
		    nginx.ingress.kubernetes.io/rewrite-target: /
		spec:
		  rules:
		  - http:
		      paths:
		      - path: /testpath
		        backend:
		          serviceName: test
		          servicePort: 80
		---
		apiVersion: networking.k8s.io/v1beta1
		kind: Ingress
		metadata:
		  name: test-ingress-2
		spec:
		  backend:
		    serviceName: testsvc
		    servicePort: 80
EOF_04
fi

# DASHBOARD & METRICS
# ===================

if [ #{$K8S_DASHBOARD} = "1" ]; then
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.1/aio/deploy/recommended.yaml
	kubectl apply -f - <<-'EOF_05'
		apiVersion: v1
		kind: ServiceAccount
		metadata:
		  name: admin-user
		  namespace: kube-system
		---
		apiVersion: rbac.authorization.k8s.io/v1
		kind: ClusterRoleBinding
		metadata:
		  name: admin-user
		roleRef:
		  apiGroup: rbac.authorization.k8s.io
		  kind: ClusterRole
		  name: cluster-admin
		subjects:
		- kind: ServiceAccount
		  name: admin-user
		  namespace: kube-system
EOF_05
	if [ ! -s "/vagrant/#{$K8S_DASH_TOKEN}" ]; then
		kubectl -n kube-system describe secrets admin-user | grep token: > "/vagrant/#{$K8S_DASH_TOKEN}" || \
		echo "WARN: Could not save Dashboard token to \"/vagrant/#{$K8S_DASH_TOKEN}\""
	fi
fi

# https://github.com/kubernetes-sigs/metrics-server
if [ #{$K8S_METRICS_SERVER} = "1" ]; then
	kubectl create -f kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml
fi

# EXAMPLE PODS
# ============
# Added 30 sec sleep because 'default' namespace might not exist yet

# https://kubernetes.io/docs/tasks/debug-application-cluster/dns-debugging-resolution/#create-a-simple-pod-to-use-as-a-test-environment
if [ #{$K8S_DNSUTILS} = "1" ]; then
	echo "Creating 'dnsutils example pod ..."
	{ sleep 30 && apply -f https://k8s.io/examples/admin/dns/dnsutils.yaml; } &
fi
if [ #{$K8S_BUSYBOX} = "1" ]; then
	echo "Creating 'busybox' example pod ..."
	{ sleep 30 && kubectl create -f https://k8s.io/examples/admin/dns/busybox.yaml; } &
fi
# helloworld: - https://kubernetes.io/docs/tasks/access-application-cluster/ingress-minikube/
# 			  - https://cloud.google.com/kubernetes-engine/docs/quickstart
if [ #{$K8S_HELLOWORLD} = "1" ]; then
	echo "Creating 'hello-world' example pod ..."
	kubectl create deployment hello-server --image=gcr.io/google-samples/hello-app:1.0
	kubectl expose deployment hello-server --type=NodePort --port=8080
fi

motd="/etc/update-motd.d/99-kubevg"
if [ ! -s "$motd" ]; then
	echo '#!/bin/sh' >"$motd" && \
	echo "printf \\"[kubevg] host0 (%s) k8s master node\\n\\" \\"#{ip_from_num(0)}\\"" >>"$motd" && \
	chmod 755 "$motd"
fi
SCRIPT
end

# -----------------------------------------------------------------------------
# WORKER NODE(S) METHOD
# -----------------------------------------------------------------------------

def node_setup_script(host_num, cluster_token, proxy_port)
	script = <<SCRIPT
if [ #{$K8S_DEBUG} -eq 255 ]; then
	echo "DEBUG: node_setup_script NODES=#{$NODES} host_num=#{host_num}"
	exit 1
fi

# SETUP ETC HOSTS
# ===============

sed 's/127.0.[0-1].1.*host#{host_num}/#{ip_from_num(host_num)}\thost#{host_num}\thost#{host_num}/' -i /etc/hosts
for i in $(seq 0 #{$NODES}); do
	# add ip and host to hosts file
	if ! grep -q host${i} /etc/hosts; then
		printf "%s\t%s\n" \
		"$(echo #{ip_from_num(0)} | sed -r "s/\.[0-9]{2} ?$/.$((10+i))/")" \
		"host${i}" | tee -a /etc/hosts
	fi
done
kubeadm join #{ip_from_num(0)}:6443 --discovery-token=#{cluster_token} --discovery-token-unsafe-skip-ca-verification || \
kubeadm join --discovery-file /vagrant/admin.conf

# SHOW/SAVE DASHBOARD
# ===================

if [ "#{host_num}" -eq "#{$NODES}" ]; then
	if [ "#{$K8S_DASHBOARD}" -eq 1 ]; then
		api="/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
		read -r -d '' txt <<-EOF_09
		1) run 'kubectl proxy --kubeconfig admin.conf' locally
		  2) open "#{$K8S_DASH_LINK}" or goto url manually:
		     http://localhost:8001${api}
		  3) to login use the token from "#{$K8S_DASH_TOKEN}"
	EOF_09
		read -r -d '' html <<-EOF_10
		<html><head><title>Kubernetes Dashboard</title><meta http-equiv="refresh" content="10; url=http://localhost:8001${api}"></head>
		<body><br>Redirecting in 10s, or click here: <a href="http://localhost:8001${api}">Kubernetes Dashboard</a><br><hr><br>
	EOF_10
		echo "$html" > "/vagrant/#{$K8S_DASH_LINK}"
		echo "Instructions:<br>" >> "/vagrant/#{$K8S_DASH_LINK}"
		echo "    $txt" | sed ':a;N;$!ba;s/\\n/<br>/g' >> "/vagrant/#{$K8S_DASH_LINK}"
		echo "<br></body></html>" >> "/vagrant/#{$K8S_DASH_LINK}"
		echo
		echo "==========================================================================="
		echo "[vg-k8s] Kubernetes Dashboard:"
		echo "  $txt"
		echo "==========================================================================="
		echo
	fi
fi

motd="/etc/update-motd.d/99-kubevg"
if [ ! -s "$motd" ]; then
	echo '#!/bin/sh' >"$motd" && \
	echo "printf \\"[kubevg] host%s (%s) k8s worker node\\n\\" \\"#{$host_num}\\" \\"#{ip_from_num(host_num)}\\"" >>"$motd" && \
	chmod 755 "$motd"
fi
SCRIPT
end

# -----------------------------------------------------------------------------
# HELPER METHODS
# -----------------------------------------------------------------------------

# This does the same as 'kubeadm token generate'
def get_cluster_token()
	if File.exist?($TOKEN_FILE) then
		token = File.read($TOKEN_FILE)
	else
		token = "#{SecureRandom.hex(3)}.#{SecureRandom.hex(8)}"
		File.write($TOKEN_FILE, token)
	end
token
end

# Generate node ip
def ip_from_num(i)
	if ($IP_RANDOM == 1) then
		if File.exist?('.ip_prefix') then
			$IP_PREFIX = File.read('.ip_prefix')
		else
			$IP_PREFIX="192.168.#{(rand(33..99)).to_s}"
			File.write('.ip_prefix', $IP_PREFIX)
			puts "Using random IP Prefix: #{$IP_PREFIX}"
		end
	end
	"#{$IP_PREFIX}.#{10+i}"
end

# Show and save dashboard info ( DISABLED: move to shell script instead )
=begin
def show_dashboard(proxy_port)
	if ($K8S_DASHBOARD == 1) then
		if File.exist?($K8S_DASH_TOKEN) then
			url = "http://localhost:#{proxy_port}/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
			if not File.exist?($K8S_DASH_LINK) then
				txt1 = %Q(1\) run \'kubectl proxy --kubeconfig admin.conf\' locally)
				txt2 = %Q(2\) open "#{$K8S_DASH_LINK}" or goto: #{url})
				txt3 = %Q(3\) to login, get the token from "#{$K8S_DASH_TOKEN}")
				html1 = %Q(<html><head><title>Kubernetes Dashboard</title></head><meta http-equiv="refresh" content="10; url=#{url}">)
				html2 = %Q(<body><br>Redirecting in 10s, or click here: <a href=#{url}">Kubernetes Dashboard</a><br><hr><br>)
				puts "[vg-k8s] Kubernetes Dashboard:"
				puts "[vg-k8s]   " + txt1
				puts "[vg-k8s]   " + txt2
				puts "[vg-k8s]   " + txt3
				File.write($K8S_DASH_LINK, html1 + html2 + 'Instructions:<br><br>' + txt1 + '<br>' + txt2  + '<br>' + txt3 + '</body></html>')
			## DISABLED: gets called on *every* vagrant invocation
			## else puts "[vg-k8s] Kubernetes Dashboard: " + url; end
			puts
			end
		end
	end
end
=end

# -----------------------------------------------------------------------------
# VAGRANT CONFIGURATION
# -----------------------------------------------------------------------------

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
		
		# Fix DNS issues related to NAT:
		# https://www.virtualbox.org/manual/ch09.html#nat_host_resolver_proxy
		if ($VB_DNSPROXY_NAT == 1) then
			vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
		end
	end

	# Enable provisioning with a shell script. Additional provisioners such as
	# Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
	# documentation for more information about their specific syntax and use.
	config.vm.provision "shell", inline: common_setup_script()

	# Generate a token to authenticate hosts joining the cluster
	cluster_token = get_cluster_token()

	if ($VB_FWD_PROXY == 1) then
		if not File.exist?(".proxy") then
			proxy_port = (rand(8001..8099)).to_s
			#puts "Forwarded Proxy port: " + proxy_port
		end
	end

	# Kubernetes hosts (host0 is master)
	$NODES=(($MASTER_NODES.to_i + $WORKER_NODES.to_i) - 1)
	(0..$NODES).each do |node|
		config.vm.define "kubevg-host#{node}" do |host|
			host.vm.network "private_network", ip: ip_from_num(node)
			host.vm.hostname = "host#{node}"
			if (node < $MASTER_NODES) then
					# Generate random proxy port to forward
					if ($VB_FWD_PROXY == 1) then
						if not File.exist?(".proxy") then
							host.vm.network "forwarded_port", guest: 8001, host: proxy_port
							File.write(".proxy", proxy_port)
						end
					end
					host.vm.provision "shell", inline: master_setup_script(cluster_token)
			else
				host.vm.provision "shell", inline: node_setup_script(node, cluster_token, proxy_port)
			end
		end
		##show_dashboard()
	end
end
