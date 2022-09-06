HEXO_PATH=/opt/node/node-v16.16.0-linux-x64/lib/node_modules/hexo-cli/bin/hexo

deploy:
	$(HEXO_PATH) clean
	$(HEXO_PATH) generate
	$(HEXO_PATH) deploy

serve:
	$(HEXO_PATH) serve