pipeline {
    agent any

    parameters {
        booleanParam(
            name: 'USE_SLIM_IMAGE',
            defaultValue: false,
            description: 'Use SlimToolkit to create and deploy a slimmed version of the image'
        )
    }

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub')
        IMAGE_TAG = "${BUILD_NUMBER}"
        ORIGINAL_IMAGE = "flask-app:${BUILD_NUMBER}-original"
        SLIM_IMAGE = "flask-app:${BUILD_NUMBER}-slim"
        NGINX_IMAGE = "mynginx:${BUILD_NUMBER}"
        DOCKERHUB_REPO = "chrisreeves1/flask-app"
    }

    stages {
        stage("File system Security Scan") {
            steps {
                sh "trivy fs --format json -o trivy-report.json ."
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-report.json', allowEmptyArchive: true
                }
            }
        }

        stage('Init') {
            steps {
                sh '''
                    docker rm -f flask-app mynginx || true
                    docker network rm new-network || true
                    docker network create new-network
                '''
            }
        }

        stage('Execute Tests') {
            steps {
                script {
                    catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
                        sh '''
                            python3 -m venv .venv
                            . .venv/bin/activate
                            pip install -r requirements.txt
                            python3 -m unittest -v test_app.py
                            deactivate
                        '''
                    }
                }
            }
        }

        stage('Build Original Images') {
            steps {
                sh '''
                    docker build -t ${ORIGINAL_IMAGE} .
                    docker build -t ${NGINX_IMAGE} -f Dockerfile.nginx .
                '''
            }
        }

        stage('Optionally Slim Image') {
            when {
                expression { return params.USE_SLIM_IMAGE }
            }
            steps {
                sh '''
                    slim build \
                      --target ${ORIGINAL_IMAGE} \
                      --tag ${SLIM_IMAGE} \
                      --http-probe=false
                '''
            }
        }

        stage('Select Final Image') {
            steps {
                script {
                    if (params.USE_SLIM_IMAGE) {
                        env.FINAL_IMAGE = env.SLIM_IMAGE
                        echo "Using slimmed image: ${env.FINAL_IMAGE}"
                    } else {
                        env.FINAL_IMAGE = env.ORIGINAL_IMAGE
                        echo "Using original image: ${env.FINAL_IMAGE}"
                    }
                }
            }
        }

        stage('Record Image Metadata') {
            steps {
                sh '''
                    docker image inspect ${FINAL_IMAGE} > image-metadata.json
                    docker image ls ${FINAL_IMAGE} > image-size.txt
                    docker history ${FINAL_IMAGE} > image-history.txt
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'image-metadata.json,image-size.txt,image-history.txt', allowEmptyArchive: true
                }
            }
        }

        stage('Image Size Gate') {
            steps {
                script {
                    def sizeBytes = sh(
                        script: "docker image inspect ${FINAL_IMAGE} --format='{{.Size}}'",
                        returnStdout: true
                    ).trim().toLong()

                    def maxBytes = 200 * 1024 * 1024

                    if (sizeBytes > maxBytes) {
                        unstable("Image is larger than 200MB")
                    }
                }
            }
}

        stage('Image Security Scan') {
            steps {
                sh '''
                    trivy image --format json -o trivy-image-report.json ${FINAL_IMAGE}
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-image-report.json', allowEmptyArchive: true
                }
            }
        }

        stage('Generate SBOM') {
            steps {
                sh '''
                    trivy image --format cyclonedx -o flask-app-sbom.cdx.json ${FINAL_IMAGE}
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'flask-app-sbom.cdx.json', allowEmptyArchive: true
                }
            }
        }

        stage('Approval Gate') {
            steps {
                input message: 'Security scan and SBOM generated. proceed?', ok: 'Yes'
            }
        }

        stage('Run Locally') {
            steps {
                sh '''
                    docker run -d --name flask-app --network new-network ${FINAL_IMAGE}
                    docker run -d -p 80:80 --name mynginx --network new-network ${NGINX_IMAGE}
                '''
            }
        }

        stage('Smoke Test') {
            steps {
                sh '''
                    for i in 1 2 3 4 5 6 7 8 9 10; do
                        echo "Smoke test attempt $i..."
                        if curl -f http://localhost/health; then
                            echo "Smoke test passed"
                            exit 0
                        fi
                        sleep 3
                    done

                    echo "Smoke test failed"
                    echo "---- Flask logs ----"
                    docker logs flask-app || true
                    echo "---- Nginx logs ----"
                    docker logs mynginx || true
                    exit 1
                '''
            }
        }

        stage('Push Image') {
            steps {
                sh '''
                    echo "$DOCKERHUB_CREDENTIALS_PSW" | docker login -u "$DOCKERHUB_CREDENTIALS_USR" --password-stdin

                    docker tag ${FINAL_IMAGE} ${DOCKERHUB_REPO}:${IMAGE_TAG}
                    docker tag ${FINAL_IMAGE} ${DOCKERHUB_REPO}:latest

                    docker push ${DOCKERHUB_REPO}:${IMAGE_TAG}
                    docker push ${DOCKERHUB_REPO}:latest
                '''
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}