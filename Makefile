# Makefile SmartOS Image Server
#
#
IMAGE_CREATOR_UUID := $(shell uuid)
IMAGE_VENDOR_UUID  := $(shell uuid)
USER               := $(shell whoami)
SCRIPT_DIR         := $(shell pwd)
NODE_PATH          := $(shell which node)
OS                 := $(shell uname)

all: npm config service info

npm:
	npm install

config:
	@sed \
	  -e "s/\"image-creator-uuid\": \".*\"/\"image-creator-uuid\": \"${IMAGE_CREATOR_UUID}\"/" \
	  -e "s/\"image-vendor-uuid\": \".*\"/\"image-vendor-uuid\": \"${IMAGE_VENDOR_UUID}\"/" \
	  config.json.in > config.json

ifeq ($(OS),SunOS)
SVC_PATH=image-server.smf.xml
service: smf
else ifeq($(OS),Linuxe)
SVC_PATH=image-server.service
service: systemd
else
service:
endif

smf:
	@echo '<?xml version="1.0"?>' > ${SVC_PATH}
	@echo '<!DOCTYPE service_bundle SYSTEM "/usr/share/lib/xml/dtd/service_bundle.dtd.1">' >> ${SVC_PATH}
	@echo '	<service_bundle type="manifest" name="image-server">' >> ${SVC_PATH}
	@echo '	<service name="site/image-server" type="service" version="1">' >> ${SVC_PATH}
	@echo '		<create_default_instance enabled="false"/>' >> ${SVC_PATH}
	@echo '			<single_instance/>' >> ${SVC_PATH}
	@echo '			<dependency name="network" grouping="require_all" restart_on="error" type="service">' >> ${SVC_PATH}
	@echo '				<service_fmri value="svc:/milestone/network:default"/>' >> ${SVC_PATH}
	@echo '			</dependency>' >> ${SVC_PATH}
	@echo '			<dependency name="filesystem" grouping="require_all" restart_on="error" type="service">' >> ${SVC_PATH}
	@echo '				<service_fmri value="svc:/system/filesystem/local"/>' >> ${SVC_PATH}
	@echo '			</dependency>' >> ${SVC_PATH}
	@echo "			<method_context working_directory=\"${SCRIPT_DIR}\">" >> ${SVC_PATH}
	@echo "				<method_credential user=\"${USER}\" group=\":default\" supp_groups=\":default\" privileges=\"basic,net_privaddr\" />" >> ${SVC_PATH}
	@echo '			</method_context>' >> ${SVC_PATH}
	@echo "			<exec_method type=\"method\" name=\"start\" exec=\"${NODE_PATH} ${SCRIPT_DIR}/server.js\" timeout_seconds=\"60\"/>" >> ${SVC_PATH}
	@echo '			<exec_method type="method" name="stop" exec=":kill" timeout_seconds="60"/>' >> ${SVC_PATH}
	@echo '			<property_group name="startd" type="framework">' >> ${SVC_PATH}
	@echo '				<propval name="duration" type="astring" value="child"/>' >> ${SVC_PATH}
	@echo '				<propval name="ignore_error" type="astring" value="core,signal"/>' >> ${SVC_PATH}
	@echo '			</property_group>' >> ${SVC_PATH}
	@echo '			<property_group name="application" type="application">' >> ${SVC_PATH}
	@echo '			</property_group>' >> ${SVC_PATH}
	@echo '			<stability value="Evolving"/>' >> ${SVC_PATH}
	@echo '			<template>' >> ${SVC_PATH}
	@echo '				<common_name>' >> ${SVC_PATH}
	@echo '					<loctext xml:lang="C">' >> ${SVC_PATH}
	@echo '						SmartOS Image Server' >> ${SVC_PATH}
	@echo '					</loctext>' >> ${SVC_PATH}
	@echo '				</common_name>' >> ${SVC_PATH}
	@echo '			</template>' >> ${SVC_PATH}
	@echo '		</service>' >> ${SVC_PATH}
	@echo '</service_bundle>' >> ${SVC_PATH}

systemd:
	@echo '[Unit]' > ${SVC_PATH}
	@echo 'Description=SmartOS image server' >> ${SVC_PATH}
	@echo 'After=network.target' >> ${SVC_PATH}	
	@echo '' >> ${SVC_PATH}
	@echo '[Service]' >> ${SVC_PATH}
	@echo 'ExecStart=${NODE_PATH} ${SCRIPT_DIR}/server.js' >> ${SVC_PATH}
	@echo 'Restart=on-failure' >> ${SVC_PATH}
	@echo 'Type=notify' >> ${SVC_PATH}
	@echo '[Install]' >> ${SVC_PATH}
	@echo 'Alias=image-server.service' >> ${SVC_PATH}

info:
	@echo ""
	@echo "--------------------------------------------------------------------------"
	@echo "Creator and Vendor UUIDs generated for config.json. You should change"
	@echo "image-creator in config.json to something more meaningful than 'internal'."
	@echo ""
	@echo "SMF Manifest generated. You can import it now by doing (as root):"
	@echo "  svccfg import image-server.smf.xml"
	@echo ""
	@echo "After importing the SMF manifest and updating config.json, you can"
	@echo "enable the image server by issuing the command (as root):"
	@echo "  svcadm enable image-server"
	@echo ""
	@echo "If you intend to use the [mkimg] script in your global zone, you will need"
	@echo "edit it and change a few settings near the top for your environment."
	@echo ""
	@echo "Please report any issues at the following location:"
	@echo "  https://github.com/nshalman/smartos-image-server/issues"
	@echo "--------------------------------------------------------------------------"
	@echo ""

clean:
	rm -f config.json
	rm -rf node_modules
	rm -f image-server.smf.xml image-server.service

.PHONY: all npm config service smf systemd info clean
