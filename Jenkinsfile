pipeline {
  agent any
  options { timestamps(); disableConcurrentBuilds() }
  stages {
    stage('Unit tests') {
      steps {
        sh 'python -m pip install -r requirements-dev.txt'
        sh 'python -m pytest -q tests'
      }
    }
    stage('Build containers') {
      steps { sh 'docker compose build' }
    }
    stage('Smoke test stack') {
      steps {
        sh 'docker compose up -d'
        sh 'python scripts/smoke_test.py'
      }
      post { always { sh 'docker compose down --remove-orphans' } }
    }
  }
  post { always { cleanWs() } }
}
