#!/bin/bash

# Create the directories for Kubernetes manifests
mkdir -p ~/trading-ai-system/kubernetes/{namespaces,storage,databases/{postgres,redis,chromadb},services/ollama}

# kubeconfig path variable
KUBECONFIG=~/.kube/config

# Namespaces file
cat > ~/trading-ai-system/kubernetes/namespaces/namespaces.yaml << 'EOF'
---
apiVersion: v1
kind: Namespace
metadata:
  name: trading-system
  labels:
    name: trading-system
    environment: development
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    name: monitoring
    environment: development
---
apiVersion: v1
kind: Namespace
metadata:
  name: databases
  labels:
    name: databases
    environment: development
EOF

# Trading data PVC
cat > ~/trading-ai-system/kubernetes/storage/trading-data-pvc.yaml << 'EOF'
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: trading-data-pvc
  namespace: trading-system
  labels:
    app: trading-system
spec:
  storageClassName: local-storage
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 5Gi
  selector:
    matchLabels:
      app: trading-system
EOF


# Storage files
cat > ~/trading-ai-system/kubernetes/storage/persistent-volumes.yaml << 'EOF'
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: trading-data-pv
  labels:
    type: local
    app: trading-system
spec:
  storageClassName: local-storage
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/trading-data"
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - trading-ai-master
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: models-pv
  labels:
    type: local
    app: trading-system
spec:
  storageClassName: local-storage
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteMany
  hostPath:
    path: "/mnt/models"
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - trading-ai-master
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgres-pv
  labels:
    type: local
    app: postgres
spec:
  storageClassName: local-path
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/postgres-data"
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - trading-ai-master
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: redis-pv
  labels:
    type: local
    app: redis
spec:
  storageClassName: local-storage
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/redis-data"
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - trading-ai-master
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: chromadb-pv
  labels:
    type: local
    app: chromadb
spec:
  storageClassName: local-storage
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/chromadb-data"
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - trading-ai-master
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: prometheus-pv
spec:
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: local-storage
  hostPath:
    path: /mnt/prometheus
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - trading-ai-master    
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: grafana-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: local-storage
  hostPath:
    path: /mnt/grafana
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - trading-ai-master
EOF

cat > ~/trading-ai-system/kubernetes/storage/storage-class.yaml << 'EOF'
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
EOF

# Postgres deployment file
cat > ~/trading-ai-system/kubernetes/databases/postgres/postgres-deployment.yaml << 'EOF'
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
  namespace: databases
  labels:
    app: postgres
data:
  POSTGRES_DB: trading_db
  POSTGRES_USER: trading_user
  PGDATA: /var/lib/postgresql/data/pgdata
---
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: databases
  labels:
    app: postgres
type: Opaque
stringData:
  POSTGRES_PASSWORD: "TradingAI2025!"  # Change this!
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: databases
  labels:
    app: postgres
spec:
  storageClassName: local-path
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: databases
  labels:
    app: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 5432
          name: postgres
        envFrom:
        - configMapRef:
            name: postgres-config
        - secretRef:
            name: postgres-secret
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - trading_user
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - trading_user
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: databases
  labels:
    app: postgres
spec:
  type: ClusterIP
  ports:
  - port: 5432
    targetPort: 5432
    protocol: TCP
    name: postgres
  selector:
    app: postgres
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-nodeport
  namespace: databases
  labels:
    app: postgres
spec:
  type: NodePort
  ports:
  - port: 5432
    targetPort: 5432
    nodePort: 30432
    protocol: TCP
    name: postgres
  selector:
    app: postgres
EOF

# Redis deployment file
cat > ~/trading-ai-system/kubernetes/databases/redis/redis-deployment.yaml << 'EOF'
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
  namespace: databases
  labels:
    app: redis
data:
  redis.conf: |
    maxmemory 2gb
    maxmemory-policy allkeys-lru
    save 900 1
    save 300 10
    save 60 10000
    appendonly yes
    appendfsync everysec
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: redis-pvc
  namespace: databases
  labels:
    app: redis
spec:
  storageClassName: local-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: databases
  labels:
    app: redis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        imagePullPolicy: IfNotPresent
        command:
        - redis-server
        - /usr/local/etc/redis/redis.conf
        ports:
        - containerPort: 6379
          name: redis
        volumeMounts:
        - name: redis-storage
          mountPath: /data
        - name: redis-config
          mountPath: /usr/local/etc/redis
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        livenessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: redis-storage
        persistentVolumeClaim:
          claimName: redis-pvc
      - name: redis-config
        configMap:
          name: redis-config
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: databases
  labels:
    app: redis
spec:
  type: ClusterIP
  ports:
  - port: 6379
    targetPort: 6379
    protocol: TCP
    name: redis
  selector:
    app: redis
---
apiVersion: v1
kind: Service
metadata:
  name: redis-nodeport
  namespace: databases
  labels:
    app: redis
spec:
  type: NodePort
  ports:
  - port: 6379
    targetPort: 6379
    nodePort: 30379
    protocol: TCP
    name: redis
  selector:
    app: redis
EOF

# ChromaDB deployment file
cat > ~/trading-ai-system/kubernetes/databases/chromadb/manual-chromadb-pv.yaml << 'EOF'
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: chromadb-pv-worker2
  labels:
    app: chromadb
spec:
  capacity:
    storage: 10Gi # Ensure this is enough for your needs, > 5Gi in your PVC
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain # Don't delete host path data on PV delete
  storageClassName: local-storage # Must match the storageClassName in your PVC/Deployment
  local:
    path: /opt/data-k8s/chromadb-pv
  nodeAffinity: # Crucial: This binds the PV to worker2 specifically
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - worker2 # Or the exact hostname of worker2
EOF

# ChromaDB deployment file
cat > ~/trading-ai-system/kubernetes/databases/chromadb/chromadb-deployment.yaml << 'EOF'
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: chromadb-pvc
  namespace: databases
  labels:
    app: chromadb
spec:
  storageClassName: local-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chromadb
  namespace: databases
  labels:
    app: chromadb
spec:
  replicas: 1
  selector:
    matchLabels:
      app: chromadb
  template:
    metadata:
      labels:
        app: chromadb
    spec:
      containers:
      - name: chromadb
        image: chromadb/chroma:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8000
          name: http
        env:
        - name: IS_PERSISTENT
          value: "TRUE"
        #- name: PERSIST_DIRECTORY
        # value: "/chroma/chroma"
        - name: ANONYMIZED_TELEMETRY
          value: "FALSE"
        volumeMounts:
        - name: chromadb-storage
          #mountPath: /chroma/chroma
          /data
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        #livenessProbe:
         # httpGet:
          #  path: /api/v1/heartbeat
           # port: 8000
          #initialDelaySeconds: 30
          #periodSeconds: 10
        #readinessProbe:
         # httpGet:
          #  path: /api/v1/heartbeat
           # port: 8000
          #initialDelaySeconds: 5
          #periodSeconds: 5
      volumes:
      - name: chromadb-storage
        persistentVolumeClaim:
          claimName: chromadb-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: chromadb
  namespace: databases
  labels:
    app: chromadb
spec:
  type: ClusterIP
  ports:
  - port: 8000
    targetPort: 8000
    protocol: TCP
    name: http
  selector:
    app: chromadb
---
apiVersion: v1
kind: Service
metadata:
  name: chromadb-nodeport
  namespace: databases
  labels:
    app: chromadb
spec:
  type: NodePort
  ports:
  - port: 8000
    targetPort: 8000
    nodePort: 30800
    protocol: TCP
    name: http
  selector:
    app: chromadb
EOF

# Ollama deployment file
cat > ~/trading-ai-system/kubernetes/services/ollama/ollama-deployment.yaml << 'EOF'
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ollama-models-pvc
  namespace: trading-system
  labels:
    app: ollama
spec:
  storageClassName: local-path
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama
  namespace: trading-system
  labels:
    app: ollama
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama
  template:
    metadata:
      labels:
        app: ollama
    spec:
      containers:
      - name: ollama
        image: ollama/ollama:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 11434
          name: http
        env:
        - name: OLLAMA_HOST
          value: "0.0.0.0"
        volumeMounts:
        - name: ollama-models
          mountPath: /root/.ollama
        resources:
          requests:
            memory: "4Gi"
            cpu: "2000m"
          limits:
            memory: "8Gi"
            cpu: "4000m"
        livenessProbe:
          httpGet:
            path: /
            port: 11434
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 11434
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: ollama-models
        persistentVolumeClaim:
          claimName: ollama-models-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: ollama
  namespace: trading-system
  labels:
    app: ollama
spec:
  type: ClusterIP
  ports:
  - port: 11434
    targetPort: 11434
    protocol: TCP
    name: http
  selector:
    app: ollama
---
apiVersion: v1
kind: Service
metadata:
  name: ollama-nodeport
  namespace: trading-system
  labels:
    app: ollama
spec:
  type: NodePort
  ports:
  - port: 11434
    targetPort: 11434
    nodePort: 31434
    protocol: TCP
    name: http
  selector:
    app: ollama
EOF

echo "Kubernetes manifest files created successfully."
