#import "@preview/touying:0.6.1": *
#import "@preview/colorful-boxes:1.3.1": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import fletcher.shapes: rect as fletcher_rect, ellipse as fletcher_ellipse, circle as fletcher_circle
#import "@preview/numbly:0.1.0": numbly
#import themes.university: *
#import "@preview/codelst:2.0.2": sourcecode

#let fletcher-diagram = touying-reducer.with(
  reduce: fletcher.diagram,
  cover: fletcher.hide
)

#set text(
  hyphenate: true,
  lang: "de"
)

#let bhtprimary = rgb("#00a0aa")

#show: university-theme.with(
  aspect-ratio: "16-9",
//  config-common(show-notes-on-second-screen: right),
  config-info(
    title: [Nebenläufigkeit in C],
    date: "06.05.2026",
    institution: "BHT Berlin",
    author: "Prof. Dr.-Ing. P. W. Dabrowski"
  ),
  config-colors(
    primary: bhtprimary,
    secondary: rgb("#ea3b07"),
    tertiary: rgb("#ffc900"),
    neutral-lightest: rgb("#ffffff"),
    neutral-darkest: rgb("#555555"),
  )
)

#show link: underline

#show figure.caption: set text(size: 16pt)

#title-slide(
  subtitle: "POSIX-Threads, Mutexes und Deadlocks",
  title: "Nebenläufigkeit in C",
  date: "27.05.2026",
  institution-name: "BHT Berlin"
)

== Agenda

- Nebenläufigkeit - warum eigentlich?
- Einordnung: Prozesse, Threads, POSIX Threads
- pthread-API:
  - Erstellung und Verwaltung von Threads
  - Thread-Sicherheit und Race Conditions
  - Mutexes als Synchronisationsmethode
  - Deadlocks und deren Vermeidung

== Lernziele

- Begriffe kennen & erklären können:
  - Thread, POSIX-Thread
  - Race Condition, Deadlock
  - Mutex
- Einfachen Thread selber implementieren können:
  - Startcode
  - Deadlocks vermeiden
  - Einfaches Producer-Consumer-Pattern oder dot product (?)

#speaker-note[
- Level 1: Reproduktion
- Level 2: Anwendung
- Level 3: Übertragung (fehlt?)
]

= Motivation


== Motivation 1: Responsivität

#slide(composer: (2fr, 1fr))[
  - Mehr Aufgaben als CPUs, z.B.:
    - Mehrere Programme offen
    - Systemdienste im Hintergrund
    - Aktualisieren des Hintergrundes
  - Lösung: Aufteilung in "parallel bearbeitbare" Aufgaben
  - Scheinbare Nebenläufigkeit: 
    - Hintereinander, nicht wirklich parallel
    - Zeitscheiben nicht wahrnehmbar 
    - System übernimmt scheduling 
][
  #figure(
    image("images/artifact.png", width: 100%),
    caption: [Grafik-Update-Problem unter Windows XP@artifact]
  )
]

== Motivation 2: Gordon Moore

#slide(composer: (2fr, 1fr))[
  - Mitbegründer von Intel
  - Moore's law: Verdopplung der Anzahl von Transistoren in Schaltkreisen ca. alle 2 Jahre
  #only(2)[
  - Verdopplung der Geschwindigkeit?
  #figure(
    image("images/mooreslaw.png", height: 55%),
    caption: [42 Jahre Mikroprozessordaten@mooreslaw]
  )]
][
  #figure(
    image("images/Gordon_Moore_1978.png", width: 100%),
    caption: [Gordon Moore in 1978@gordonmoore]
  )
]

== Caveat: Amdahl's law & Realität


#slide(composer: (2fr, 1fr))[
  - Ideal: Mehr Kerne = schneller
  - Amdahl's law: Code nur teilweise parallel 
    - $ "Speedup" = 1/((1-f)+f/n) $
    - f: Parallelisierbarer Anteil des Codes
    - n: Anzahl Cores
    - Diminishing returns bei mehr Kernen
    - Konvergiert gegen Maximal-Speedup
  - Realistischer: Overhead pro Task
    - Speedup vs. Overhead
    - Konvergiert nicht, Core-Optimum
][
  #figure(
    image("images/speedup.png", width: 100%),
    caption: [Beschleunigung durch Parallelität@scaling]
  )
]

= Threading

== Threads vs. Prozesse

#slide(composer: (1fr, 1fr))[
  - Prozess: Komplettes "Programm"
    - Hoher Overhead
    - Starke Isolation
    - Kommunikation: Shared memory, pipes, sockets...
    - Verteilbar zwischen Systemen
  - Thread: Einzelne Methode 
    - Geringer Overhead, nutzt PCB des Prozesses
    - Nutzt heap des Prozesses
    - Eigener Stack
    - Nicht verteilbar
][
  #figure(
    table(
      columns: (auto, auto),
      table.header([*PCB*], [*TCB*]),
      [PID], [TID],
      [Scheduling], [Scheduling],
      [Prog. counter], [Prog. counter],
      [Registers], [Registers],
      [Stack pointer], [Stack pointer],
      [], [PCB reference],
      [Memory Info \ (page table etc.)], [],
      [IPC info], [],
      [Process structure], [],
      [I/O status], [],
      [...], []
    ),
    caption: [Schematischer Vergleich Process Control Block und Thread Control Block]
  )
]

== Pthreads

- Thread ist an sich nur ein Konzept
- Historisch: Herstellerspezifisches Handling -> Inkompatibilität
- 1996: C-API für UNIX-Threads in IEEE POSIX 1003.1c @IEEEpthreads
- Implementationen, die sich daran halten: POSIX threads, auch Ptheads
- Funktionalität:
  - Thread-Management
  - Synchronisation von Ressourcen-Zugriffen
  - Zugriff auf Thread-Metadaten
- Themen heute:
  - Thread erstellen (create), beenden (join)
  - Speicherzugriff koordinieren (mutex)
  - Konzepte auf andere Thread-APIs anwendbar

== Thread-Erstellung

#sourcecode[```c 
int pthread_create(pthread_t *thread, 
    const pthread_attr_t *attr,
    void *(*work_func)(void *),
    void *arg);```]

- thread: UID für den Thread
- attr: Thread-Attribute: detached, stack pointer, stack size. Oder NULL.
- work_func: Funktion mit dem auszuführenden Code
- arg: Argument für work_func

Implizit: main ist immer ein Thread, weitere müssen explizit erstellt werden.

== Einfaches Beispiel

#slide(composer: (2.8fr, 1fr))[
  #text(size: 14pt, sourcecode[```c
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
```]
)

Warum nicht 1, 2, 3, 4, 5 running? Immer gleich?
][
  #text(size: 14pt, sourcecode[```text
Creating thread 0
Creating thread 1
Creating thread 2
  Thread 1 running.
Creating thread 3
  Thread 2 running.
  Thread 0 running.
Creating thread 4
  Thread 3 running.
Creating thread 5
  Thread 4 running.
  Thread 5 running.```
  ])
]

== Thread sauber beenden

#slide(composer: (1fr, 1fr))[
  #sourcecode[```c 
    int pthread_exit(void *retval);
  ```]

  - Beendet Thread
    - Gibt Stack nicht frei
    - Beendet keine Kinder-Threads\ -> in main statt `exit(0);`
  - retval: 
    - Rückgabewert, oft int
    - Bitte nicht vom Stack!
  ][
  #sourcecode[```c 
    int pthread_join(
      pthread_t thread, 
      void **retval);
  ```]

  - Blockiert, bis `thread` beendet ist
  - Gibt Thread-Ressourcen frei
  - retval: Rückgabewert von `pthread_exit`
  - Exakt 1 join/thread: 
    - Mehrere joins: undefiniert
    - Kein join: leak
    - Alternative: detached
]

#speaker-note[
  - Ressourcenfreigabe: Stack, TCB - aber nicht heap, muss man selber aufräumen!
  - Rückgabe am besten über malloc auf heap und dann free. Alternativ static, aber bei vielen Threads schlecht (lifetime = program lifetime)
  - Return-value von pthread_join: Status code/error, falls join nicht geklappt hat
]

== Join und return value 

#slide(composer: (2.8fr, 1fr))[
  #text(size: 14pt, sourcecode[```c
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

```]
)

Warum jetzt 0, 1, 2, 3, 5, 5? Immer gleich?
][
  #text(size: 14pt, sourcecode[```text
Result of thread 0: 0
Result of thread 1: 1
Result of thread 2: 4
Result of thread 3: 9
Result of thread 4: 16
Result of thread 5: 25
```])
]

== Join und return value - Einfachere Alternative?

#slide(composer: (2.8fr, 1fr))[
  #text(size: 14pt, sourcecode[```c
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#define NUM_THREADS 6

void *do_work(void *thread_id) {
  int result = (long)thread_id * (long)thread_id;
  pthread_exit(&result);
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

```]
)

#only(1)[Was kommt jetzt als result raus? Ideen?]
#only(2)[Der Stack hat's gefressen -> Heap oder static (!).]

#speaker-note[
  - Nie stack pointer zurückgeben, ist immer undefined behavior!
]

][
  #only(2)[
  #text(size: 14pt, sourcecode[```text
Result of thread 0: 0
Result of thread 1: 0
Result of thread 2: 0
Result of thread 3: 0
Result of thread 4: 0
Result of thread 5: 0
```])]
]

== Shared memory

- Threads haben eigenen Stack, aber gemeinsamen Heap
- Nützlich für gemeinsamen Datenzugriff
- Aber: Nicht-atomare Operationen sind gefährlich! Beispiel: `x += 1`:
  - Lädt x in Register
  - Erhöht Wert um 1
  - Schreibt Wert aus Register in x
- Was passiert, wenn zwei Threads das gleichzeitig machen?

== Race condition: Beispiel

#slide(composer: (2.4fr, 1fr))[
  #text(size: 14pt, sourcecode[```c
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
    pthread_create(&threads[tid], NULL, &do_work, (void *)&result);
  }
  pthread_exit(NULL);
}

```]
)

][
  #text(size: 14pt, sourcecode[```text
Incremented result: 89561
Incremented result: 93444
Incremented result: 93001
Incremented result: 113924
Incremented result: 121814
Incremented result: 121145
  ```])
]

== Mutex 

- Immer Vorsicht bei Zugriff auf gemeinsame Daten (-> heap)
- Auch bei library-Methoden: Nie von thread-safety ausgehen, wenn nicht explizit!
- Selber sicheren Datenzugriff gestalten: mutex (mutually exclusive)
  - Definiert Anweisungen, die nur von einem Thread gleichzeitig ausgeführt werden können -> Geschützter Bereich
  - Zugriff wird über eine Variable gesichert, die Status verwaltet:
    - Ob der Bereich frei oder belegt ist
    - Welcher Thread gerade in dem Bereich ist
    - Welche Threads gerade warten
  - Unterschiedliche geschützte Bereiche durch unterschiedliche Variablen möglich

== Mutex in Pthreads

#sourcecode[```c
int pthread_mutex_lock(pthread_mutex_t *lock);
int pthread_mutex_unlock(pthread_mutex_t *lock);
```
]

- `lock`: Variable, "auf der" synchronisiert wird
- Return-Wert: 0 bei Erfolg, sonst Fehlercode
- `pthread_mutex_lock`: 
  - Versucht, `lock` zu belegen
  - Blockiert, falls das nicht möglich ist (selber Thread: deadlock!)
  - Alternativ: `pthread_mutex_trylock`
- `pthread_mutex_unlock`:
  - Gibt `lock` frei
  - Falls mehrere andere Threads warten: OS-Scheduling entscheidet

== Mutex gegen race condition: Beispiel

#slide(composer: (2.4fr, 1fr))[
  #text(size: 14pt, sourcecode[```c
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#define NUM_THREADS 6

pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

void *do_work(void *result) {
  long *res = (long *)result;
  for(int i=0; i<100000; i++) {
    pthread_mutex_lock(&lock);
    *res += 1;
    pthread_mutex_unlock(&lock);
  }
  printf("Incremented result: %ld\n", *res);
  pthread_exit(NULL);
}

int main(int argc, char *argv[]) {
  long result = 0;
  pthread_t threads[NUM_THREADS];
  for(long tid=0; tid<NUM_THREADS; tid++) {
    pthread_create(&threads[tid], NULL, &do_work, (void *)&result);
  }
  pthread_exit(NULL);
}

```]
)

][
  #text(size: 14pt, sourcecode[```text
Incremented result: 478896
Incremented result: 510844
Incremented result: 574294
Incremented result: 576115
Incremented result: 598955
Incremented result: 600000
  ```])
]




== Erfolgskontrolle: Kurz-Quizzes zwischendurch?

- TODO

== Quellen

#set text(size: 12pt)

#bibliography("sources.bib", title: none)

#focus-slide[
Danke für Ihre Aufmerksamkeit!

...Fragen?
]

== Mehr Argumente: Struct


#slide(composer: (2.8fr, 1fr))[
  #text(size: 14pt, sourcecode[```c
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


```]
)

][
  #text(size: 14pt, sourcecode[```text
Thread 2 got arg 8.
Thread 3 got arg 7.
Thread 0 got arg 10.
Thread 4 got arg 6.
Thread 5 got arg 5.
Thread 1 got arg 9.
  ```])
]


