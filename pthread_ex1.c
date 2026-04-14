#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#define NUM_THREADS 6

void *do_work(void *thread_id) {
  printf("  Thread %ld running.\n", (long)thread_id);
  pthread_exit(NULL);
}

int main(int argc, char *argv[]) {
  pthread_t threads[NUM_THREADS];
  for(long tid=0; tid<NUM_THREADS; tid++) {
    printf("Creating thread %ld\n", tid);
    int rc = pthread_create(&threads[tid], NULL, &do_work, (void *)tid );
    if (rc) {
      printf("ERROR %d\n", rc);
      exit(-1);
    }
  }
  pthread_exit(NULL);
}
