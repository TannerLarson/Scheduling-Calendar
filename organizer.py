# This Python file uses the following encoding: utf-8
import sys
import json
import pickle
import os.path

from PySide2.QtGui import QGuiApplication
from PySide2.QtQml import QQmlApplicationEngine
from PySide2.QtWidgets import QApplication
from PySide2.QtCore import Slot, QUrl, QObject, Signal, Property, QStringListModel

data_json = QStringListModel()


class Workers(QObject):

    def __init__(self):
        super().__init__()
        self.names = ["Tanner", "Jennie", "Kyle", "Rob", "Kaitlyn", "Maria"]
        self._can_kneel = []
        self._can_stand = []
        self._spanish_speaker = []

    @Slot(str)
    def can_kneel(self, name):
        i = self.names.index(name)
        return _can_kneel[i]

    @Slot(str)
    def can_stand(self, name):
        i = self.names.index(name)
        return _can_stand[i]

    @Slot(str)
    def speaks_spanish(self, name):
        i = self.names.index(name)
        return _spanish_speaker[i]


class Bridge(QObject):

    def __init__(self):
        super().__init__()
        self.data_dict = {} # Look in Bridge.save for more information on this
        self.engine = QQmlApplicationEngine

    @Slot(str, str, str, str)
    def save(self, workers, positions, blackoutTiles, calendarColumns):
        self.data_dict = {
            # String list
            'worker_names': json.loads(workers),
            # String list
            'position_names': json.loads(positions),
            # Entries will be [x position, y position] of blackout tiles
            'blackout_positions': json.loads(blackoutTiles),
            # Entries will be [all [name, y position] of name tiles]
            'column_data': json.loads(calendarColumns)
        }
        with open('organizer_data.pkl', 'wb') as pickle_file:
            pickle.dump(self.data_dict, pickle_file)

    @Slot()
    def load_qml(self):
        self.load_from_pickle()
        self.engine.load(QUrl('view.qml'))

    def load_from_pickle(self):
        # Check for a previous save
        if os.path.exists('organizer_data.pkl'):
            with open('organizer_data.pkl', 'rb') as pickle_file:
                self.data_dict = pickle.load(pickle_file)
            data_json.setStringList([json.dumps(self.data_dict)])

        # Fill any undefined values in data_dict with default values
        if 'worker_names' not in self.data_dict.keys():
            self.data_dict['worker_names'] = ["Tanner", "Kyle", "Jennie", "Rob"]

        if 'position_names' not in self.data_dict.keys():
            self.data_dict['position_names'] = ["Position A", "Postion B", "Position C", "Position D"]


def main():
    app = QGuiApplication(sys.argv)
    bridge = Bridge()
    workers = Workers()

    #Set up engine and connect to qml
    engine = QQmlApplicationEngine(app)
    engine.rootContext().setContextProperty("bridge", bridge)
    engine.rootContext().setContextProperty("workers", workers)
    engine.rootContext().setContextProperty("saveData", data_json)
    bridge.engine = engine
    bridge.load_qml()
    if not engine.rootObjects():
        print("Root Objects not found")
        sys.exit(-1)

    sys.exit(app.exec_())


if __name__ == "__main__":
    main()
