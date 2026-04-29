package incusos

import "encoding/yaml"

#SupportedHost: "um760" | "ms02-1" | "ms02-2" | "ms02-3"

host: *"um760" | #SupportedHost @tag(host)

#Defaults: {
	provisioning: {
		publicIP:        "10.10.20.1"
		subnet:          "10.10.20.0/24"
		gateway:         "10.10.20.1"
		netmask:         "255.255.255.0"
		artifactBaseURL: "http://10.10.20.1:18080"
		leaseTime:       86400
		nameServers: [
			"10.10.10.1",
			"1.1.1.1",
		]
	}
	tinkerbell: {
		namespace:        "tinkerbell"
		image2diskAction: "quay.io/tinkerbell/actions/image2disk:2a7c298fe0292737371ca11913e3c0c3bf794981"
	}
	image: {
		indexURL:          "https://images.linuxcontainers.org/os/index.json"
		baseURL:           "https://images.linuxcontainers.org/os"
		arch:              "x86_64"
		size:              "50G"
		seedOffset:        2148532224
		firstNodeArtifact: "incusos-operation-first-node-x86_64.img.gz"
	}
	identity: {
		secretsFile: "compute/incusos/bootstrap-client.sops.yaml"
	}
	router: {
		artifactDir: "/config/containers/incusos-artifacts"
	}
}

#Host: {
	name!:           string
	hostname!:       string
	bootstrapRole!:  "first-node" | "joiner"
	mac!:            string
	disk!:           string
	provisioningIP!: string
	managementIP!:   string
}

hosts: {
	um760: #Host & {
		name:           "um760"
		hostname:       "um760"
		bootstrapRole:  "first-node"
		mac:            "38:05:25:34:25:d0"
		disk:           "/dev/nvme0n1"
		provisioningIP: "10.10.20.10"
		managementIP:   "10.10.10.10"
	}
	"ms02-1": #Host & {
		name:           "ms02-1"
		hostname:       "ms02-1"
		bootstrapRole:  "joiner"
		mac:            ""
		disk:           "/dev/nvme0n1"
		provisioningIP: "10.10.20.11"
		managementIP:   "10.10.10.11"
	}
	"ms02-2": #Host & {
		name:           "ms02-2"
		hostname:       "ms02-2"
		bootstrapRole:  "joiner"
		mac:            ""
		disk:           "/dev/nvme0n1"
		provisioningIP: "10.10.20.12"
		managementIP:   "10.10.10.12"
	}
	"ms02-3": #Host & {
		name:           "ms02-3"
		hostname:       "ms02-3"
		bootstrapRole:  "joiner"
		mac:            ""
		disk:           "/dev/nvme0n1"
		provisioningIP: "10.10.20.13"
		managementIP:   "10.10.10.13"
	}
}

selectedHost: hosts[host] & {
	bootstrapRole: "first-node" | error("joiner flow is not implemented yet")
	mac:           string & !="" | error("mac is required")
}

cfgArtifactName: #Defaults.image.firstNodeArtifact
cfgArtifactURL:  "\(#Defaults.provisioning.artifactBaseURL)/\(cfgArtifactName)"

imageBuildConfig: {
	host: {
		name:           selectedHost.name
		hostname:       selectedHost.hostname
		bootstrapRole:  selectedHost.bootstrapRole
		mac:            selectedHost.mac
		disk:           selectedHost.disk
		provisioningIP: selectedHost.provisioningIP
		managementIP:   selectedHost.managementIP
	}
	provisioning: #Defaults.provisioning
	tinkerbell:   #Defaults.tinkerbell
	image: {
		indexURL:    #Defaults.image.indexURL
		baseURL:     #Defaults.image.baseURL
		arch:        #Defaults.image.arch
		size:        #Defaults.image.size
		seedOffset:  #Defaults.image.seedOffset
		artifactName: cfgArtifactName
		artifactURL:  cfgArtifactURL
	}
	identity: #Defaults.identity
	router:   #Defaults.router
}

kubernetesYAML: yaml.MarshalStream(kubernetesObjects)
