Once cloned the repo with ~/.zshrc gkebaselab() in your new lab sandbox directory, 

You can use `code .` to open the directory as a visual studio code workspace and user terminal commands from there.

__Instructions for Use of Bash Script (gcloud):__
1. Navigate to the `gcloud/` directory.
2. Run the commands in your terminal (`00-deploy.sh` and then `01-cleanup.sh`).
	1. `./00-deploy.sh`
	or
	2. `./00-deploy.sh -y` or `./00-deploy.sh -Y` or `./00-deploy.sh --auto-approve`

__Instructions for Use of Terraform:__
1. Navigate to the `tf/` directory.
2. Run `terraform init` to initialize the provider.
3. Run `terraform apply` to create the infrastructure.

in terminal, 
`open -a "Google Chrome" $(cat cluster-url.txt)`





`obsidian_tmp` for opening obsidian in that workspace.

Eventually if you want to document to a git repo use `gitinitpub()` or `gitinitpub myreponame`

