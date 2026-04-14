#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#define NUM_THREADS 6

pthread_mutex_t lock1 = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t lock2 = PTHREAD_MUTEX_INITIALIZER;
int account1 = 1000;
int account2 = 1000;

void *transfer(void *amount) {
  pthread_mutex_lock(&lock1);
  pthread_mutex_lock(&lock2);
  account1 += *(int*)amount;
  account2 -= *(int*)amount;
  printf("Balances: %d, %d\n", account1, account2);
  pthread_mutex_unlock(&lock2);
  pthread_mutex_unlock(&lock1);
  pthread_exit(NULL);
}

void *get_difference(void *arg) {
  pthread_mutex_lock(&lock1);
  pthread_mutex_lock(&lock2);
  printf("Balance difference: %d\n", (account1-account2));
  pthread_mutex_unlock(&lock2);
  pthread_mutex_unlock(&lock1);
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

