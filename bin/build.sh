aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 939121955975.dkr.ecr.us-east-1.amazonaws.com
docker buildx build --platform linux/amd64 -f ./Dockerfile -t wallet-app .
docker tag wallet-app:latest 939121955975.dkr.ecr.us-east-1.amazonaws.com/wallet-app:latest
docker push 939121955975.dkr.ecr.us-east-1.amazonaws.com/wallet-app:latest