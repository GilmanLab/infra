package incusos

import "encoding/yaml"

#Hardware: {
	apiVersion: "tinkerbell.org/v1alpha1"
	kind:       "Hardware"
	metadata: {
		name:      selectedHost.name
		namespace: #Defaults.tinkerbell.namespace
	}
	spec: {
		agentID: selectedHost.mac
		disks: [{
			device: selectedHost.disk
		}]
		interfaces: [{
			dhcp: {
				arch:     #Defaults.image.arch
				hostname: selectedHost.hostname
				ip: {
					address: selectedHost.provisioningIP
					gateway: #Defaults.provisioning.gateway
					netmask: #Defaults.provisioning.netmask
				}
				lease_time: #Defaults.provisioning.leaseTime
				mac:        selectedHost.mac
				name_servers: #Defaults.provisioning.nameServers
				uefi: true
			}
			netboot: {
				allowPXE:      true
				allowWorkflow: true
			}
		}]
	}
}

#TemplateData: {
	name:           "incusos-operation-first-node"
	version:        "0.1"
	global_timeout: 10800
	tasks: [{
		name:   "write incusos first-node image"
		worker: "{{.device_1}}"
		volumes: [
			"/dev:/dev",
			"/dev/console:/dev/console",
		]
			actions: [{
				name:    "stream incusos first-node image"
				image:   #Defaults.tinkerbell.image2diskAction
				timeout: 7200
				environment: {
					IMG_URL:    cfgArtifactURL
					DEST_DISK:  "{{ index .Hardware.Disks 0 }}"
					COMPRESSED: "true"
				}
			}]
	}]
}

#Template: {
	apiVersion: "tinkerbell.org/v1alpha1"
	kind:       "Template"
	metadata: {
		name:      "incusos-operation-first-node"
		namespace: #Defaults.tinkerbell.namespace
	}
	spec: {
		data: yaml.Marshal(#TemplateData)
	}
}

#Workflow: {
	apiVersion: "tinkerbell.org/v1alpha1"
	kind:       "Workflow"
	metadata: {
		name:      "incusos-operation-\(selectedHost.name)"
		namespace: #Defaults.tinkerbell.namespace
	}
	spec: {
		templateRef: #Template.metadata.name
		hardwareRef: #Hardware.metadata.name
		hardwareMap: {
			device_1: selectedHost.mac
		}
	}
}

kubernetesObjects: [
	#Hardware,
	#Template,
	#Workflow,
]
