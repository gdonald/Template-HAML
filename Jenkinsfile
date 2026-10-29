// Runs in the home lab's Jenkins, in one pod running the Raku CI image built
// from raku-ci/ in the devops repo. When every stage passes, Jenkins reports
// the continuous-integration/jenkins/branch status, which starts
// .github/workflows/ci.yml on the same commit.

def buildPod = '''
  apiVersion: v1
  kind: Pod
  spec:
    containers:
      - name: ci
        image: harbor.home.gregdonald.com/raku/ci:latest
        imagePullPolicy: Always
        command: ["sleep"]
        args: ["infinity"]
        resources:
          requests:
            cpu: "2"
            memory: 4Gi
          limits:
            cpu: "4"
            memory: 4Gi
'''

pipeline {
  agent {
    kubernetes {
      defaultContainer 'ci'
      yaml buildPod
    }
  }

  options {
    disableConcurrentBuilds(abortPrevious: true)
    timeout(time: 60, unit: 'MINUTES')
  }

  environment {
    HAML_BENCH_ITERS = '10'
    HAML_RUN_BENCH = '1'
  }

  // A failing test stage marks the build failed and the stages after it
  // still run, so one run reports every failure.
  stages {
    stage('dependencies') {
      steps {
        sh 'zef install --/test --force-install https://github.com/gdonald/BDD-Behave.git'
        sh 'zef install --deps-only --/test --test-depends .'
      }
    }

    stage('prove6-direct') {
      steps {
        catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
          sh './test.raku prove6-direct'
        }
      }
    }

    stage('prove6-ast') {
      steps {
        catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
          sh './test.raku prove6-ast'
        }
      }
    }

    stage('behave') {
      steps {
        catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
          sh './test.raku behave'
        }
      }
    }

    stage('benchmark') {
      steps {
        catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
          sh 'behave --benchmark specs/bench/'
        }
      }
    }
  }
}
