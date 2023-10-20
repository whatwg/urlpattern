SHELL=/bin/bash -o pipefail
.PHONY: local remote deploy

remote: spec.bs
	@ (HTTP_STATUS=$$(curl https://api.csswg.org/bikeshed/ \
	                       --output spec.html \
	                       --write-out "%{http_code}" \
	                       --header "Accept: text/plain, text/html" \
	                       -F die-on=warning \
	                       -F md-Text-Macro="COMMIT-SHA LOCAL COPY" \
	                       -F file=@spec.bs) && \
	[[ "$$HTTP_STATUS" -eq "200" ]]) || ( \
		echo ""; cat spec.html; echo ""; \
		rm -f spec.html; \
		exit 22 \
	);

local: spec.bs
	bikeshed spec spec.bs spec.html --md-Text-Macro="COMMIT-SHA LOCAL COPY"

deploy: spec.bs
	curl --remote-name --fail https://resources.whatwg.org/build/deploy.sh
	bash ./deploy.sh
