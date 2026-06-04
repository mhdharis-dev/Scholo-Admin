    if [ "$1" == "prod" ]; then
      echo "🚀 Deploying to PRODUCTION..."
      flutter build web -t lib/main_prod.dart && firebase deploy --only hosting:prod --project prod
    else
      echo "🧪 Deploying to TESTING..."
      flutter build web -t lib/main_test.dart && firebase deploy --only hosting:test --project test
    fi
