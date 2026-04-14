#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#define NUM_THREADS 6

int maxmueller = 1000;
int lisemueller = 1000;
pthread_mutex_t lock_max = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t lock_lise = PTHREAD_MUTEX_INITIALIZER;

void *transfer(void *amount) {
  pthread_mutex_lock(&lock_lise);
  pthread_mutex_lock(&lock_max);
  maxmueller += *(int*)amount;
  lisemueller -= *(int*)amount;
  printf("Max: %d, Lise: %d\n", maxmueller, lisemueller);
  pthread_mutex_unlock(&lock_max);
  pthread_mutex_unlock(&lock_lise);
  pthread_exit(NULL);
}

void *get_difference(void *arg) {
  pthread_mutex_lock(&lock_max);
  pthread_mutex_lock(&lock_lise);
  printf("Max hat %d mehr als Lise\n", (maxmueller-lisemueller));
  pthread_mutex_unlock(&lock_lise);
  pthread_mutex_unlock(&lock_max);
  pthread_exit(NULL);
}

int main(int argc, char *argv[]) {
  pthread_t threads[2*NUM_THREADS];
  for(long tid=0; tid<NUM_THREADS; tid++) {
    pthread_create(&threads[tid+1], NULL, &transfer, (void *)&tid );
    pthread_create(&threads[2*tid], NULL, &get_difference, NULL );
  }
  pthread_exit(NULL);
}

