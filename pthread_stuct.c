#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#define NUM_THREADS 6

struct thread_args {
  int tid, arg;
};

struct thread_args args_arr[NUM_THREADS];

void *do_work(void *thread_arg) {
  struct thread_args *arg = (struct thread_args *) thread_arg;
  printf("Thread %d got arg %d.\n", arg->tid, arg->arg);
  pthread_exit(NULL);
}

int main(int argc, char *argv[]) {
  pthread_t threads[NUM_THREADS];
  for(long tid=0; tid<NUM_THREADS; tid++) {
    struct thread_args *arg = &args_arr[tid];
    arg->tid = tid;
    arg->arg = 10-tid;
    pthread_create(&threads[tid], NULL, &do_work, (void *)arg );
  }
  pthread_exit(NULL);
}


