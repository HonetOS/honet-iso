output:
	sudo mkarchiso -v -w ./working -o ./output ./releng/
clean:
	sudo rm -rf output/
	sudo rm -rf working/
