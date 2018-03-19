#!/usr/bin/env python3
# file: move_to_bps.py
# Automatically move created and modified files from the source dir to the target dir.

import os.path
import shutil
import time
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from time import gmtime, strftime

relative_src_path = r"../../../../script-output/Blueprints/"
relative_dst_path = r"./bp/"


class Handler(FileSystemEventHandler):
    @staticmethod
    def on_any_event(event):
        if event.is_directory:
            return
        if event.event_type == "created" or event.event_type == "modified":
            target_file_path = os.path.join(relative_dst_path, os.path.basename(event.src_path))
            print(strftime("%Y-%m-%d %H:%M:%S", gmtime()) + " | File change detected: " + event.src_path + ", copying to " + target_file_path)
            shutil.copyfile(event.src_path, target_file_path)


class Watcher:
    def __init__(self, path):
        self.observer = Observer()
        self.path = path

    def run(self):
        event_handler = Handler()
        self.observer.schedule(event_handler, self.path, recursive=True)
        self.observer.start()
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            self.observer.stop()
            print("Ended.")

        self.observer.join()


if __name__ == "__main__":
    print("Automatically copying from " + relative_src_path + " to " + relative_dst_path)

    ob = Watcher(relative_src_path)
    ob.run()