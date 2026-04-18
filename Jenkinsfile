pipeline {
  agent any
  tools {
    nodejs 'node16'
  }    
  environment {
    SCANNER_HOME = tool 'sonar-scanner'
    SNYK_TOKEN = credentials('snyk-api-token')
  }
  stages {
    stage('Git Clone') {
      steps {
        git branch: 'main', url: 'https://github.com/rohitG7496/tradeIn.git'
      }
    }
    stage('Sonar Scan') {
      steps {
        withSonarQubeEnv('sonar') {
          sh """
            ${SCANNER_HOME}/bin/sonar-scanner \
            -Dsonar.projectName=TradeIn-Project \
            -Dsonar.projectKey=TradeIn-Project \
            -Dsonar.sources=Frontend,Backend
          """
        }
      }
    }
    /*stage('Quality Gate Check') {
      steps 
        timeout(time: 5, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: false
        }
      }
    } */
    stage('snyk scan for SCA') {
      when {
        expression { app == 'frontend' || app == 'frontend  backend'}
      }
      steps {
        sh """#!/bin/bash
          npm install -g snyk snyk-to-html
          cd Frontend
          npm install --legacy-peer-deps
          snyk test --json --severity-threshold=high > snyk_results.json || true
          snyk monitor --project-name="TradeIn-Frontend"
          snyk-to-html -i snyk_results.json -o snyk-report.html
        """  
        script {
          // 1. Upload to S3 (adding attachment flag to force file download when clicked)
          sh "aws s3 cp Frontend/snyk-report.html s3://tradein-reports/snyk-reports/snyk-report-${env.BUILD_NUMBER}.html --acl public-read --content-disposition attachment"
          
          // 2. Direct S3 static URL
          def directS3Url = "https://tradein-reports.s3.amazonaws.com/snyk-reports/snyk-report-${env.BUILD_NUMBER}.html"

          // 3. Send sweet Slack message
          slackSend(
            channel: "C06NJGMR7PY",
            color: "good",
            message: "✅ *Security Scan Complete!*\nGreat job team! The Snyk report for *${env.JOB_NAME}* (Build #${env.BUILD_NUMBER}) is ready. 🚀\n<${directS3Url}|📥 Click here to safely download the report>",
            tokenCredentialId: "slack-bot-token",
            botUser: true
          )
        }
      }
    } //synk 
    /*stage('Build Docker Frontend Image and Docker Image Scan Through Trivy ') {
      steps {
        sh """#!/bin/bash
          cd Frontend
          aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin 616812761800.dkr.ecr.ap-south-1.amazonaws.com
          docker buildx build -t 616812761800.dkr.ecr.ap-south-1.amazonaws.com/frontend:latest .
          wget https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/html.tpl
          trivy image --format template --template "@html.tpl" -o Frontend-Dockerfile.html 616812761800.dkr.ecr.ap-south-1.amazonaws.com/frontend:latest 
        """    
      }
    } //close build stage     */  
  } //close stages
} //close pipeline
