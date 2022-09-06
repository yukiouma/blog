HEXO_PATH=/opt/node/node-v16.16.0-linux-x64/lib/node_modules/hexo-cli/bin/hexo

deploy:
	$(HEXO_PATH) deploy

clean:
	$(HEXO_PATH) clean

generate:
	$(HEXO_PATH) generate

serve:
	$(HEXO_PATH) serve

new:
	$(HEXO_PATH) new $(name)

tag:
	$(HEXO_PATH) new page tags

cat:
	$(HEXO_PATH) new page categories
