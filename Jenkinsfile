// overall pipeline -> options. stages(options, errorHandling, post actions) -> pipeline post actions.  


pipeline{
    agent any
    options{
        timeout(time: 5, "MINUTES")
        timestamps() 
    }
    stages{
        stage("make a directory"){
            options{
                retry(2)
            }
            steps{
                sh "mkdir jenkins-test"
            }
        }
        stage("add a file"){
            steps{
                sh "touch jenkins-test/file1.txt"
            }
        }
    } 
    post {
        always {
            archiveArtifacts artifacts: "jenkins-test/*.txt", allowEmptyArchive: true 
        }
    }
}