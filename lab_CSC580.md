# 🌟 Lab Activity Guide: Simulating Parallel Processing on Hadoop/YARN

This guide details how to simulate parallel processing in a Dockerized Hadoop & Hive environment by scaling the cluster workers, forcing block splitting in HDFS, and running MapReduce/Hive jobs.

---

## 📋 Core Architectural Concepts
1. **Storage Parallelism (HDFS Block Splitting):** HDFS splits large files into blocks and distributes them across multiple DataNodes.
2. **Compute Parallelism (YARN & MapReduce):** YARN schedules Map tasks to run in parallel on the specific nodes holding the target data blocks (Data Locality).
3. **Cluster Scaling:** Docker Compose allows scaling worker containers dynamically.

---

## 📋 Prerequisites
* Docker Desktop configured with at least **8 GB of RAM** (allocated via *Settings → Resources*).
* Clone of the repository and initial setup done (JDBC driver downloaded, `.env` file configured).

---

## 🛠️ Step 1: Spin Up & Scale the Cluster
By scaling the worker containers, we simulate a multi-node cluster on a single machine.

1. Open a terminal/PowerShell in the cloned `bigdata-hadoop-hive-lab` directory.
2. Launch the services while scaling the storage node (`datanode`) and compute node (`nodemanager`) to **3 instances each**:
   ```powershell
   docker-compose up -d --scale datanode=3 --scale nodemanager=3
   ```
3. Verify that all 3 datanodes and 3 nodemanagers are active:
   ```powershell
   docker-compose ps
   ```

---

## 🖥️ Step 2: Verify Cluster Capacity via Web UIs
Open your browser to inspect how the master node views this new distributed resource capacity:
1. **HDFS NameNode UI:** Go to [http://localhost:9870](http://localhost:9870) and click **Datanodes** in the top menu. You should see three distinct DataNodes listed.
2. **YARN Resource Manager UI:** Go to [http://localhost:8088](http://localhost:8088) and click **Nodes** in the left menu. You should see three NodeManagers ready to run containers, with their memory/VCores aggregated.

---

## 📂 Step 3: Simulate Distributed Storage (HDFS Block Splitting)
By default, the HDFS block size is 128 MB. A file like `devicestatus.txt` (~13.9 MB) in `/home/student/training/data/` would normally fit into a single block, resulting in only 1 Map task (no compute parallelism). 

We will upload this file while overriding the block size to **2 MB (2,097,152 bytes)**. This forces HDFS to split the file into `ceil(13.9 / 2) = 7` blocks and distribute them across the 3 DataNodes.

1. Access the student gateway shell (**edge-node**):
   ```powershell
   docker exec -it edge-node bash
   ```
2. Create an input directory in HDFS:
   ```bash
   hdfs dfs -mkdir -p /user/student/input
   ```
3. Upload `devicestatus.txt` forcing a **2 MB block size**:
   ```bash
   hdfs dfs -Ddfs.blocksize=2097152 -put /home/student/training/data/devicestatus.txt /user/student/input/
   ```
4. Verify how the file is split and where the blocks are placed:
   ```bash
   hdfs fsck /user/student/input/devicestatus.txt -files -blocks -locations
   ```
   * **What to observe:** You will see a list of **7 blocks** distributed across the different `datanode` hosts. You can also view this visually on the NameNode UI ([http://localhost:9870](http://localhost:9870)) by going to **Utilities → Browse the file system**, navigating to `/user/student/input/devicestatus.txt`, and clicking on it to see block locations.

---

## ⚙️ Step 4: Simulate Parallel Processing (MapReduce Job)
When we submit a MapReduce job to process our HDFS file, YARN reads the block distribution metadata and schedules **7 Mapper tasks** (one per block) to process the chunks in parallel.

1. Inside the `edge-node` container shell, check the available MapReduce examples:
   ```bash
   ls $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar
   ```
2. Run the WordCount MapReduce job on the split file:
   ```bash
   yarn jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.2.1.jar wordcount /user/student/input/devicestatus.txt /user/student/output/wordcount_result
   ```
3. **Immediately open the YARN Resource Manager UI ([http://localhost:8088](http://localhost:8088)):**
   * Click on the active Application ID.
   * Under the execution details, inspect the **Running Containers**. You will see YARN dynamically allocating execution containers across the 3 different NodeManager worker nodes to process the 7 Map tasks in parallel.
   * Note the metrics showing `Map tasks = 7` and `Reduce tasks = 1`.

4. Confirm the job output:
   ```bash
   hdfs dfs -cat /user/student/output/wordcount_result/part-r-00000 | head -n 20
   ```

---

## 🧮 Step 5: CPU-bound Parallel Execution (Pi Job)
If you want to observe YARN container allocation without copying files to HDFS, you can run the built-in Monte Carlo Pi estimator. We can tell it to use **15 Mappers** running in parallel:

1. Inside the `edge-node` container shell, run:
   ```bash
   yarn jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.2.1.jar pi 15 100000
   ```
2. Monitor the YARN Web UI ([http://localhost:8088](http://localhost:8088)). You will see 15 map tasks running concurrently across the 3 NodeManager workers.

---

## 🛢️ Step 6: Parallelism inside Apache Hive (SQL-to-MapReduce)
Hive converts SQL statements into MapReduce stages. When you run queries on datasets spanning multiple HDFS blocks, the query processing is distributed automatically.

1. Inside the `edge-node` container shell, log into Hive using Beeline:
   ```bash
   beeline -u jdbc:hive2://hive-server:10000 -n hive -p hive_lab_2024
   ```
2. Create an external table pointing to your HDFS dataset:
   ```sql
   CREATE TABLE IF NOT EXISTS devicestatus (
     dt STRING,
     device_id STRING,
     latitude DOUBLE,
     longitude DOUBLE
   )
   ROW FORMAT DELIMITED
   FIELDS TERMINATED BY ','
   STORED AS TEXTFILE;
   
   -- Load the HDFS split file into Hive
   LOAD DATA INPATH '/user/student/input/devicestatus.txt' INTO TABLE devicestatus;
   ```
3. Run an aggregation query that forces a Shuffle/Sort phase (triggers MapReduce):
   ```sql
   SELECT device_id, COUNT(*) as cnt FROM devicestatus GROUP BY device_id ORDER BY cnt DESC LIMIT 10;
   ```
4. **Observe:** The terminal will display progress updates from the YARN Job. YARN splits the read and aggregation actions across the 3 NodeManager workers according to the underlying block structure.

---

## 🧹 Step 7: Clean Up
After the lab activity, you can spin down the scaled containers.
```powershell
# Stop and clean up containers
docker-compose down

# Optional: Add '-v' to remove named volumes and reset your HDFS/Hive database
docker-compose down -v
```
