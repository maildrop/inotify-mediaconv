
.PHONY: all clean install install-systemd-service

all:

install: mediaconvd.sh 
	install mediaconvd.sh /usr/local/sbin/mediaconvd

install-systemd-service: mediaconvd.service
	cp mediaconvd.service /etc/systemd/system/mediaconvd.service
	systemctl daemon-reload

clean:
	find . -maxdepth 1 -type f -name '*~' -delete

