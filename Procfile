web: bundle exec thrust bin/start-app
redis: redis-server config/redis.conf
workers: FORK_PER_JOB=false INTERVAL=0.1 bundle exec resque-pool
scheduler: RUN_RESQUE_SCHEDULER=true bundle exec rake resque:scheduler
