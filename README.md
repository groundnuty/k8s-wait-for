[![Latest Release](https://img.shields.io/github/v/release/groundnuty/k8s-wait-for?logo=GitHub)](https://github.com/groundnuty/k8s-wait-for/releases/latest)
[![Build Status](https://travis-ci.org/groundnuty/k8s-wait-for.svg?branch=master)](https://travis-ci.org/groundnuty/k8s-wait-for)
[![Codacy Badge](https://api.codacy.com/project/badge/Grade/9e61e311725b4015a24f294c591746b1)](https://www.codacy.com/app/groundnuty/k8s-wait-for?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=groundnuty/k8s-wait-for&amp;utm_campaign=Badge_Grade)
[![Latest Docker Yag](https://img.shields.io/docker/v/groundnuty/k8s-wait-for?logo=docker)](https://microbadger.com/images/groundnuty/k8s-wait-for "Get your own version badge on microbadger.com")
[![Latest Docker Tag Details](https://images.microbadger.com/badges/image/groundnuty/k8s-wait-for.svg?logo=docker)](https://microbadger.com/images/groundnuty/k8s-wait-for "Get your own image badge on microbadger.com")

# k8s-wait-for

> This tool is still actively used and working stably despite not too frequent commits! Pull requests are most welcome!

A simple script that allows waiting for a k8s service, job or pods to enter the desired state.

## Running

You can start simple. Run it on your cluster in a namespace you already have something deployed:

```bash
kubectl run --generator=run-pod/v1 k8s-wait-for --rm -it --image groundnuty/k8s-wait-for:v1.3 --restart Never --command /bin/sh
```

Read `--help` and play with it!

```bash
/ > wait_for.sh -h
This script waits until a job, pod or service enter a ready state. 

wait_for.sh job [<job name> | -l<kubectl selector>]
wait_for.sh pod [<pod name> | -l<kubectl selector>]
wait_for.sh service [<service name> | -l<kubectl selector>]

Examples:
Wait for all pods with a following label to enter 'Ready' state:
wait_for.sh pod -lapp=develop-volume-gluster-krakow

Wait for all pods with a following label to enter 'Ready' or 'Error' state:
wait_for.sh pod-we -lapp=develop-volume-gluster-krakow

Wait for all the pods in that job to have a 'Succeeded' state:
wait_for.sh job develop-volume-s3-krakow-init

Wait for all the pods in that job to have a 'Succeeded' or 'Failed' state:
wait_for.sh job-we develop-volume-s3-krakow-init

Wait for at least one pod in that job to have 'Succeeded' state, does not mind some 'Failed' ones:
${0##*/} job-wr develop-volume-s3-krakow-init

Wait for all selected pods to enter the 'Ready' state:
wait_for.sh pod -l"release in (develop), chart notin (cross-support-job-3p)"
```

## Example

A complex Kubernetes deployment manifest (generated by [helm](https://github.com/kubernetes/helm)). This deployment waits for one job to finish and 2 pods to enter a ready state.

```bash
kind: StatefulSet
metadata:
  name: develop-oneprovider-krakow
  labels:
    app: develop-oneprovider-krakow
    chart: oneprovider-krakow
    release: develop
    heritage: Tiller
    component: oneprovider
  annotations:
    version: "0.2.17"
spec:
  selector:
    matchLabels:
      app: develop-oneprovider-krakow
      chart: oneprovider-krakow
      release: develop
      heritage: Tiller
      component: "oneprovider"
  serviceName: develop-oneprovider-krakow
  template:
    metadata:
      labels:
        app: develop-oneprovider-krakow
        chart: oneprovider-krakow
        release: develop
        heritage: Tiller
        component: "oneprovider"
      annotations:
        version: "0.2.17"
    spec:
      initContainers:
        - name: wait-for-onezone
          image: groundnuty/k8s-wait-for:v1.3
          imagePullPolicy: Always
          args:
            - "job"
            - "develop-onezone-ready-check"
        - name: wait-for-volume-ceph
          image: groundnuty/k8s-wait-for:v1.3
          imagePullPolicy: Always
          args:
            - "pod"
            - "-lapp=develop-volume-ceph-krakow"
        - name: wait-for-volume-gluster
          image: groundnuty/k8s-wait-for:v1.3
          imagePullPolicy: Always
          args:
            - "pod"
            - "-lapp=develop-volume-gluster-krakow"
      containers:
      - name: oneprovider
        image: docker.onedata.org/oneprovider:ID-a3a9ff0d78
        imagePullPolicy: Always
```

## Complex deployment use case

This container is used extensively in deployments of Onedata system [onedata/charts](https://github.com/onedata/charts) to specify dependencies. It leverages Kubernetes [init containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/), thus providing:

- a detailed event log in `kubectl describe <pod>`, on what init container is pod hanging at the moment.
- a comprehensive view in `kubectl get pods` output where init containers are shown in a form `Init:<ready>/<total>`

Example output from the deployment run of ~16 pod with dependencies just after deployment:

```bash
NAME                                                   READY     STATUS              RESTARTS   AGE
develop-cross-support-job-3p-krk-3-lis-c-b4nv1         0/1       Init:0/1            0          11s
develop-cross-support-job-3p-krk-3-par-c-lis-n-z7x6w   0/1       Init:0/1            0          11s
develop-cross-support-job-3p-krk-3-x9719               0/1       Init:0/1            0          11s
develop-cross-support-job-3p-krk-g-par-3-ztvz0         0/1       Init:0/1            0          11s
develop-cross-support-job-3p-krk-g-v5lf2               0/1       Init:0/1            0          11s
develop-cross-support-job-3p-krk-n-par-3-pnbcm         0/1       Init:0/1            0          11s
develop-cross-support-job-3p-lis-3-cpj3f               0/1       Init:0/1            0          11s
develop-cross-support-job-3p-par-n-8zdt2               0/1       Init:0/1            0          11s
develop-cross-support-job-3p-par-n-lis-c-kqdf0         0/1       Init:0/1            0          11s
develop-oneclient-krakow-2773392814-wc1dv              0/1       Init:0/3            0          11s
develop-oneclient-lisbon-3267879054-2v6cg              0/1       Init:0/3            0          9s
develop-oneclient-paris-2076479302-f6hh9               0/1       Init:0/3            0          9s
develop-onedata-cli-krakow-1801798075-b5wpj            0/1       Init:0/1            0          11s
develop-onedata-cli-lisbon-139116355-fwtjv             0/1       Init:0/1            0          10s
develop-onedata-cli-paris-2662312307-9z9l1             0/1       Init:0/1            0          11s
develop-oneprovider-krakow-3634465102-tftc6            0/1       Pending             0          10s
develop-oneprovider-lisbon-3034775369-8n31x            0/1       Init:0/3            0          8s
develop-oneprovider-paris-3034358951-19mhf             0/1       Init:0/3            0          10s
develop-onezone-304145816-dmxn1                        0/1       ContainerCreating   0          11s
develop-volume-ceph-krakow-479580114-mkd1d             0/1       ContainerCreating   0          11s
develop-volume-ceph-lisbon-1249181958-1f0mt            0/1       ContainerCreating   0          9s
develop-volume-ceph-paris-400443052-dc347              0/1       ContainerCreating   0          9s
develop-volume-gluster-krakow-761992225-sj06m          0/1       Running             0          11s
develop-volume-gluster-lisbon-3947152141-jlmvb         0/1       Running             0          8s
develop-volume-gluster-paris-3588749681-9bnw8          0/1       ContainerCreating   0          11s
develop-volume-nfs-krakow-2528947555-6mxzt             1/1       Running             0          10s
develop-volume-nfs-lisbon-3473018547-7nljf             0/1       ContainerCreating   0          11s
develop-volume-nfs-paris-2956540513-4bdzt              0/1       ContainerCreating   0          11s
develop-volume-s3-krakow-23786741-pdxtj                0/1       Running             0          9s
develop-volume-s3-krakow-init-gqmmp                    0/1       Init:0/1            0          11s
develop-volume-s3-lisbon-3912793669-d4xh5              0/1       Running             0          10s
develop-volume-s3-lisbon-init-mq9nk                    0/1       Init:0/1            0          11s
develop-volume-s3-paris-124394749-qwt18                0/1       Running             0          8s
develop-volume-s3-paris-init-jb4k3                     0/1       Init:0/1            0          11s
```

1 min after, you can see the changes in the *Status* column:

```bash
develop-cross-support-job-3p-krk-3-lis-c-b4nv1         0/1       Init:0/1          0          1m
develop-cross-support-job-3p-krk-3-par-c-lis-n-z7x6w   0/1       Init:0/1          0          1m
develop-cross-support-job-3p-krk-3-x9719               0/1       Init:0/1          0          1m
develop-cross-support-job-3p-krk-g-par-3-ztvz0         0/1       Init:0/1          0          1m
develop-cross-support-job-3p-krk-g-v5lf2               0/1       Init:0/1          0          1m
develop-cross-support-job-3p-krk-n-par-3-pnbcm         0/1       Init:0/1          0          1m
develop-cross-support-job-3p-lis-3-cpj3f               0/1       Init:0/1          0          1m
develop-cross-support-job-3p-par-n-8zdt2               0/1       Init:0/1          0          1m
develop-cross-support-job-3p-par-n-lis-c-kqdf0         0/1       Init:0/1          0          1m
develop-oneclient-krakow-2773392814-wc1dv              0/1       Init:0/3          0          1m
develop-oneclient-lisbon-3267879054-2v6cg              0/1       Init:0/3          0          58s
develop-oneclient-paris-2076479302-f6hh9               0/1       Init:0/3          0          58s
develop-onedata-cli-krakow-1801798075-b5wpj            0/1       Init:0/1          0          1m
develop-onedata-cli-lisbon-139116355-fwtjv             0/1       Init:0/1          0          59s
develop-onedata-cli-paris-2662312307-9z9l1             0/1       Init:0/1          0          1m
develop-oneprovider-krakow-3634465102-tftc6            0/1       Init:1/3          0          59s
develop-oneprovider-lisbon-3034775369-8n31x            0/1       Init:2/3          0          57s
develop-oneprovider-paris-3034358951-19mhf             0/1       PodInitializing   0          59s
develop-onezone-304145816-dmxn1                        0/1       Running           0          1m
develop-volume-ceph-krakow-479580114-mkd1d             1/1       Running           0          1m
develop-volume-ceph-lisbon-1249181958-1f0mt            1/1       Running           0          58s
develop-volume-ceph-paris-400443052-dc347              1/1       Running           0          58s
develop-volume-gluster-krakow-761992225-sj06m          1/1       Running           0          1m
develop-volume-gluster-lisbon-3947152141-jlmvb         1/1       Running           0          57s
develop-volume-gluster-paris-3588749681-9bnw8          1/1       Running           0          1m
develop-volume-nfs-krakow-2528947555-6mxzt             1/1       Running           0          59s
develop-volume-nfs-lisbon-3473018547-7nljf             1/1       Running           0          1m
develop-volume-nfs-paris-2956540513-4bdzt              1/1       Running           0          1m
develop-volume-s3-krakow-23786741-pdxtj                1/1       Running           0          58s
develop-volume-s3-lisbon-3912793669-d4xh5              1/1       Running           0          59s
develop-volume-s3-paris-124394749-qwt18                1/1       Running           0          57s
```
## Troubleshooting

Verify that you can access the Kubernetes API from within the k8s-wait-for container by running `kubectl get services`. If you get a permissions error like   

`Error from server (Forbidden): services is forbidden: User "system:serviceaccount:default:default" cannot list resource "services" in API group "" in the namespace "default"`   

the pod lacks the permissions to perform the `kubectl get` query. To fix this, follow the instrctions for the 'pod-reader' role and clusterrole at   

https://kubernetes.io/docs/reference/access-authn-authz/rbac/#kubectl-create-role

or use these command lines which add services and deployments to the pods in those examples:      
`kubectl create role pod-reader --verb=get --verb=list --verb=watch --resource=pods,services,deployments`   

`kubectl create rolebinding default-pod-reader --role=pod-reader --serviceaccount=default:default --namespace=default`

An extensive discussion on the problem of granting necessary permisions and a number of example solutions can be found [here](https://github.com/groundnuty/k8s-wait-for/issues/6).
