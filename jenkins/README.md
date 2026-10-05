# Jenkins

- `plugins.txt` – plugins installed into the Jenkins image.
- `app.Dockerfile` – multi-stage build of the Java app (Maven build → Tomcat 9 image); used by the pipeline.
- The pipeline itself is the `Jenkinsfile` in the repository root.

Jenkins credentials the pipeline expects:

| ID | Type | Purpose |
|----|------|---------|
| `aws-terraform-access` | AWS credentials | ECR push, EC2 lookup |
| `aws_devopscourse_key` | SSH private key | SSH to the Tomcat server (Ansible) |
