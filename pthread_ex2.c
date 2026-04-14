#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#define NUM_THREADS 6

void *do_work(void *thread_id) {
  int *result = malloc(sizeof(int));
  *result = (long)thread_id * (long)thread_id;
  pthread_exit(result);
}

int main(int argc, char *argv[]) {
  pthread_t threads[NUM_THREADS];
  for(long tid=0; tid<NUM_THREADS; tid++) {
    pthread_create(&threads[tid], NULL, &do_work, (void *)tid );
  }
  for(long tid=0; tid<NUM_THREADS; tid++) {
    void *result;
    pthread_join(threads[tid], &result);
    printf("Result of thread %ld: %d\n", tid, *(int *)result);
  }
  pthread_exit(NULL);
}

