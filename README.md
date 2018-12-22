# Infrastructure

Manages the infrastructure I use for side projects. Before any of the GCP
terraform can be used, it is required that we provision a service account and
key for the admin user:

```shell
gcloud iam service-accounts create terraform --project lawrjone
gcloud iam service-accounts keys create ~/.config/gcloud/lawrjone-terraform.json --iam-account terraform@lawrjone.iam.gserviceaccount.com --project lawrjone

for role in 'roles/owner' 'roles/storage.admin'; do
  gcloud projects add-iam-policy-binding lawrjone --project lawrjone --role "${role}" --member serviceAccount:terraform@lawrjone.iam.gserviceaccount.com
done

# Enable core API services
for api in 'cloudresourcemanager' 'cloudbilling' 'iam' 'compute'; do
  gcloud services enable "${api}.googleapis.com"
done
```

This is not the traditional example where the terraform account exists within an
administrative project that parents sub-project: I expect not to be creating
many other GCP projects, given this is a private side-project.

Set `GOOGLE_APPLICATION_CREDENTIALS=~/.config/gcloud/lawrjone-terraform.json` to
activate the terraform credentials.
