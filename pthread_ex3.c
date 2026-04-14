#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#define NUM_THREADS 6

void *do_work(void *result) {
  long *res = (long *)result;
  for(int i=0; i<100000; i++) {
    *res += 1;
  }
  printf("Incremented result: %ld\n", *res);
  pthread_exit(NULL);
}

int main(int argc, char *argv[]) {
  long result = 0;
  pthread_t threads[NUM_THREADS];
  for(long tid=0; tid<NUM_THREADS; tid++) {
    pthread_create(&threads[tid], NULL, &do_work, (void *)&result );
  }
  pthread_exit(NULL);
}

