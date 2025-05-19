#TODO
import random
import requests
import logging
import time
import json
import functools
import os
from confluent_kafka import Consumer

log = logging.getLogger('main')

FORMAT = '%(asctime)s - %(levelname)s - %(message)s'
logging.basicConfig(format=FORMAT)  # , stream=sys.stdout
log.setLevel(logging.INFO)
log.info(f'rApp START')
random.seed(2)


class Cell:
    def __init__(self, name: str, load: float, frequency: float):
        self.name = name
        self.load = load
        self.frequency = frequency

class ViaviCell:
    def __init__(self, id: int, name: str):
        self.id = id
        self.name = name
        self.nr_cell_relations = []

class O1ManagerBase:
    def adjust_cell_offset(self, cell_id, new_offset_value):
        raise NotImplementedError

    def fetch_cell_data(self):
        raise NotImplementedError

    def get_cell_id_from_name(self, name):
        raise NotImplementedError

class O1SimulatorManager(O1ManagerBase):
    def __init__(self):
        self.url_base = "http://controller:8181/rests/data/"
        self.url = self.url_base + "network-topology:network-topology/topology=topology-netconf/node={}/yang-ext:mount/_3gpp-common-managed-element:ManagedElement=ManagedElement-002/_3gpp-nr-nrm-gnbdufunction:GNBDUFunction=GNBDUFunction-001/_3gpp-nr-nrm-nrcelldu:NRCellDU={}/attributes/ssbOffset"
        self.user = "admin"
        self.password = "Kp8bJ4SXszM0WXlhak3eHlcse2gAw84vaoGGmJvUy2U"
        self.headers = {'Content-type': 'application/yang-data+json', 'Accept': 'application/yang-data+json'}
        self.o1_simulator_node_id = None

    def fetch_cell_data(self):
        log.info("Fetching data")
        response = requests.get(self.url_base, auth=(self.user, self.password), headers=self.headers, verify=False)
        if not response.ok:
            log.warning("Fetching cell data from O1-simulator failed: " + str(response))
            return
        if 'node' not in response.json()['network-topology:network-topology']['topology'][0]:
            log.info("Fetching data from SDN Controller successfull, but no nodes retrieved yet.")
            return
        node_id = None
        for node in response.json()['network-topology:network-topology']['topology'][0]['node']:
            if node['netconf-node-topology:connection-status'] == "connected":
                if node_id is not None:
                    log.warning("Multiple O1-simulators seem to be Connected at the same time!")
                node_id = node['node-id']
        log.info("O1 simulator node name found: " + node_id)
        self.o1_simulator_node_id = node_id

    def adjust_cell_offset(self, cell_name, new_offset_value):
        if self.o1_simulator_node_id is None:
            self.fetch_cell_data()
        current_offset = requests.get(self.url.format(self.o1_simulator_node_id, cell_name), auth=(self.user, self.password), headers=self.headers, verify=False).json()['_3gpp-nr-nrm-nrcelldu:ssbOffset']
        log.info("Current offset for cell {} is {}.".format(cell_name, str(current_offset)))
        print(requests.get(self.url.format(self.o1_simulator_node_id, cell_name), auth=(self.user, self.password), headers=self.headers, verify=False).json())
        # TODO float does not work, thus using int
        payload = {'_3gpp-nr-nrm-nrcelldu:ssbOffset': int(new_offset_value)}
        #if current_state == 'UNLOCKED':
        #    payload = {'_3gpp-nr-nrm-nrcelldu:administrativeState': 'LOCKED'}
        #else:
        #    payload = {'_3gpp-nr-nrm-nrcelldu:administrativeState': 'UNLOCKED'}
        log.info("path is: " + self.url.format(self.o1_simulator_node_id, cell_name))
        response = requests.put(self.url.format(self.o1_simulator_node_id, cell_name), auth=(self.user, self.password), json=payload)
        if not response.ok:
            log.warning("Adjusting cells failed: " + str(response))
        log.info('Response status code is: {}'.format(response.status_code))

class ViaviManager(O1ManagerBase):
    def __init__(self):
        self.cell_url_base = "/O1/CM/"
        ## I do not know why is this number always the same. Thus, we have it hardcoded here.
        self.cell_url_managed_element_part = "ManagedElement=1193046"
        self.cell_url_cucp_function_part = self.cell_url_managed_element_part + ",GnbCuCpFunction=1,NrCellCu="
        self.url_prefix = "http://"
        self.viavi_address = os.environ['VIAVI_ADDRESS']
        self.viavi_port = os.environ['VIAVI_PORT']
        self.viavi_auth = os.environ['VIAVI_USER'], os.environ['VIAVI_PASS']
        self.cell_data = {}
        self.cell_data_by_id = {}

    def adjust_cell_offset(self, cell_id, new_offset_value):
        if len(self.cell_data) == 0:
            self.fetch_cell_data()
        cell = self.cell_data_by_id[cell_id]
        # For now, we assume offset value should be the same for all relations of one cell. So, below we set the new value for all cell's relations.
        for cell_relation_id in cell.nr_cell_relations:
            url = self.url_prefix + self.viavi_address + ':' + self.viavi_port + self.cell_url_base + self.cell_url_cucp_function_part + str(cell.id) + ',NRCellRelation=' + str(cell_relation_id)
            #print("Data before change: " + str(requests.get(url, auth=self.viavi_auth).json()))
            log.info("Adjusting offset on " + url + " with new value " + str(new_offset_value))

            payload = { "attributes": { "cellIndividualOffset": {"rsrpOffsetSsb": new_offset_value, "rsrqOffsetSsb": 0, "sinrOffsetSsb": 0 } } }
            response = requests.put(url, auth=self.viavi_auth, json=payload)
            if not response.ok:
                raise Exception("Adjusting cell data from Viavi failed: " + str(response))
            #print("Data after change: " + str(requests.get(url, auth=self.viavi_auth).json()))

    def fetch_cell_data(self):
        url = self.url_prefix + self.viavi_address + ':' + self.viavi_port + self.cell_url_base + self.cell_url_managed_element_part
        log.info("Fetch cells on url " + url)
        response = requests.get(url, auth=self.viavi_auth)
        if not response.ok:
            log.warning("Fetching cell data from Viavi failed: " + str(response))
        gnb_function = response.json()['GnbCuCpFunction']
        if len(gnb_function) != 1:
            raise Exception("Unexpected number of GnbCuCpFunctions received from Viavi!")
        data = gnb_function[0]
        for cell in data['NrCellCu']:
            cell_id = int(cell['id'])
            cell_name = cell['viavi-attributes']['cellName']
            viavi_cell = ViaviCell(cell_id, cell_name)
            #print(cell['NRCellRelation'])
            for cell_relation in cell['NRCellRelation']:
                offsets = cell_relation['attributes']['cellIndividualOffset']
                # We assume that all three offsets are the same, but we should check just to be sure
                #if len({offsets['rsrpOffsetSsb'], offsets['rsrqOffsetSsb'], offsets['sinrOffsetSsb']}) != 1:
                 #   log.warning("Offsets do not match!")
                # We can store current offset as well here, but we did not need it for now, so let's save memory. But, it can be added in the future.
                viavi_cell.nr_cell_relations.append(int(cell_relation['id']))
            self.cell_data[cell_name] = viavi_cell
            self.cell_data_by_id[cell_id] = viavi_cell
            log.info('Adding cell {} and its relations {}.'.format(cell_name, str(self.cell_data[cell_name].nr_cell_relations)))

    def get_cell_id_from_name(self, name):
        return self.cell_data[name].id

class KafkaClient:
    def __init__(self):
        self.creds_client_id = os.environ['CREDS_CLIENT_ID']
        self.creds_client_secret = os.environ['CREDS_CLIENT_SECRET']
        self.creds_service_url = os.environ['AUTH_SERVICE_URL']
        self.input_kafka_topic = os.environ['INPUT_TOPIC']
        self.kafka_consumer_port = os.environ['CONSUMER_PORT']
        self.kafka_server = os.environ['KAFKA_SERVER'] + ':' + os.environ['CONSUMER_PORT']
        self.rapp_id = "ts-rapp"
        self.gid = "ts-rapp-group"
        self.cid = "cid-0"
        self.consumer_polling_timeout = 1
        self.consumer = Consumer({'bootstrap.servers': self.kafka_server,
                                  'security.protocol': 'sasl_plaintext',
                                  'sasl.mechanisms': 'OAUTHBEARER',
                                  'oauth_cb': functools.partial(self.get_token, []),
                                  'group.id': self.gid,
                                  'client.id': self.cid})

    def subscribe_to_rapp_topic(self):
        log.info("Connecting Consumer with Kafka server " + self.kafka_server + " and subscribing to topic " + self.input_kafka_topic)
        self.consumer.subscribe([self.input_kafka_topic])

    def poll_message(self):
        return self.consumer.poll(self.consumer_polling_timeout)

    def close_consumer(self):
        self.close()

    def get_token(self, args, config):
        """Taken from https://github.com/confluentinc/confluent-kafka-python/blob/v2.6.0/examples/oauth_producer.py"""

        log.info("Retrieving token for Kafka from Keycloak")
        payload = {
            'grant_type': 'client_credentials'
        }
        resp = requests.post(self.creds_service_url,
                             auth=(self.creds_client_id, self.creds_client_secret),
                             data=payload)
        token = resp.json()
        log.info("Token received: " + token['access_token'])
        return token['access_token'], time.time() + float(token['expires_in'])

class ComputationWorker():
    def __init__(self):
        if os.environ['USE_O1_SIMULATOR'] == "true":
            self.o1_manager = O1SimulatorManager()
        else:
            self.o1_manager = ViaviManager()
        self.kafka_consumer = KafkaClient()

        #TODO
    )

    def work(self):
        log.info("Starting ComputingWorker")
        cell_info_set = False
        self.kafka_consumer.subscribe_to_rapp_topic()
        self.o1_manager.fetch_cell_data()
        while True:
            time.sleep(5)
            msg = self.kafka_consumer.poll_message()
            if msg is None:
                log.info("Polling from Kafka: no message")
                continue
            if msg.error():
                log.info("Kafka consumer error: {}".format(msg.error()))
                continue

            data = msg.value().decode('utf-8')
            json_data = json.loads(data)
            if 'event' not in json_data:
                raise Exception("Unexpected message received: " + str(data))
            log.info("Kafka topic received Viavi_perf3gpp event from Viavi!")
            input_data_parsed = {}
            # json includes measTypes specifying order of values later on, so we need to determine that
            dl_load_key_id = json_data['event']['perf3gppFields']['measDataCollection']['measInfoList'][0]['measTypes']['sMeasTypesList'].index("RRU.PrbTotDl") + 1
            frequency_key_id = json_data['event']['perf3gppFields']['measDataCollection']['measInfoList'][0]['measTypes']['sMeasTypesList'].index("Viavi.Frequency") + 1
            cell_name_id = json_data['event']['perf3gppFields']['measDataCollection']['measInfoList'][0]['measTypes']['sMeasTypesList'].index("Viavi.Cell.Name") + 1
            for meas in json_data['event']['perf3gppFields']['measDataCollection']['measInfoList'][0]['measValuesList']:
                cell_name, cell_load, cell_frequency = None, None, None
                for key_value in meas['measResults']:
                    key = int(key_value['p'])
                    value = key_value['sValue']
                    if key == cell_name_id:
                        cell_name = value
                    elif key == dl_load_key_id:
                        cell_load = float(value)/100
                    elif key == frequency_key_id:
                        cell_frequency = float(value)
                log.info('Received metric: Cell_name: {}, Load: {}, Frequency: {}.'.format(cell_name, str(cell_load), str(cell_frequency)))
                if cell_name in input_data_parsed:
                    log.warning('Duplicate cell name appeared!')
                if cell_name is None and cell_load is None and cell_frequency is None:
                    log.warning('Either cell name, load or frequency was not received!')
                input_data_parsed[cell_name] = Cell(cell_name, cell_load, cell_frequency)
            new_offsets = self.run_algorithm(input_data_parsed, time.time(), cell_info_set)
            cell_info_set = True
            if len(new_offsets) == 0:
                log.info("No cell offset changes for now.")
            else:
                log.info('Offsets set by the algorithm: {}.'.format(new_offsets))
            for cell_id in new_offsets:
                self.o1_manager.adjust_cell_offset(cell_id, new_offsets[cell_id])

        log.info("Kafka consumer closing connection...")
        self.kafka_consumer.close()

    def run_algorithm(self, input_data, time, cell_info_set):
        """
        Example of parameters for the run_algorithm method:
        timstamp_s: float - The timestamp in seconds for the algorithm run.
        cells_id: List[int] - List of cell IDs.
        cells_load: List[float] - List of load values for each cell, range (0.0 - 1.0).
        cells_freq_mhz: List[float] - List of frequency values for each cell in MHz.
        """
        log.info("Computing cell offsets...")

        cell_ids, cell_loads, cell_frequencies = [], [], []
        for cell in input_data.values():
            cell_ids.append(self.o1_manager.get_cell_id_from_name(cell.name))
            cell_loads.append(cell.load)
            cell_frequencies.append(cell.frequency)
        if cell_info_set:
            log.info("Cells already uploaded.")
        else:
            log.info("Adding cells to TS")
            self.traffic_steering_rapp.update_cell_list(cell_ids, cell_frequencies)
        # Run the algorithm and get offsets
       #TODO
        """
        Offsets set by the algorithm {cell_id: cell_individual_offset}
        """
        return offsets

if __name__ == "__main__":
    worker = ComputationWorker()
    worker.work()
