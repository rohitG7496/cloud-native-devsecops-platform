pipeline {
  agent any
  tools {
    nodejs 'node18'
  }    
  environment {
    SCANNER_HOME = tool 'sonar-scanner'
  }
  stages {
    stage('Git Clone') {
      steps {
        git branch: 'main', url: 'https://github.com/rohitG7496/tradeIn-devsecops.git'
      }
    }
    /*stage('Sonar Scan') {
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
    stage('Quality Gate Check') {
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: false
        }
      }
    } */
    /*stage('Trivy Package scanning') {
      steps {
        sh 'wget https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/html.tpl'
        sh 'trivy fs --format template --template "@html.tpl" -o sca-report.html .'
      }
    }   */
    stage('Build Docker Frontend Image and Docker Image Scan Through Trivy ') {
      steps {
        sh """#!/bin/bash
          cd Frontend
          aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin 616812761800.dkr.ecr.ap-south-1.amazonaws.com
          docker buildx build -t 616812761800.dkr.ecr.ap-south-1.amazonaws.com/frontend:latest .
          wget https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/html.tpl
          trivy image --format template --template "@html.tpl" -o Frontend-Dockerfile.html 616812761800.dkr.ecr.ap-south-1.amazonaws.com/frontend:latest 
        """    
      }
    } //close build stage       
  } //close stages
} //close pipeline
