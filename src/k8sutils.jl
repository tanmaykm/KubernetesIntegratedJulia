# Layer that integrates with k8s
# - deploys pipeline stages on k8s
# - monitors the status of the pipeline stages

using Kuber

const projectdir = dirname(@__DIR__)

const ApiImpl = Kuber.ApiImpl
const CoreV1 = ApiImpl.Typedefs.CoreV1

const Pod = CoreV1.Pod
const Service = CoreV1.Service
const PodList = CoreV1.PodList
const WatchEvent = CoreV1.WatchEvent

"""
    k8s_run

Runs either a Pod or a Service on the k8s cluster
"""
k8s_run(ctx::KuberContext, typ::Symbol, entity) = put!(ctx, entity)
k8s_run(ctx::KuberContext, entity::Pod) = k8s_run(ctx, :Pod, entity)
k8s_run(ctx::KuberContext, entity::Service) = k8s_run(ctx, :Service, entity)

"""
    k8s_delete

Deletes a Pod or Service from the k8s cluster
"""
function k8s_delete(ctx::KuberContext, typ::Symbol, name::String)
    @debug("deleting", typ, name)
    try
        delete!(ctx, typ, name)
    catch
        # ignore not found exceptions
    end
end

"""
    k8s_run_pipeline_command(ctx, name, method)

Runs one of the commands that constitute the pipeline for
preparing the search server for deployment. Each command
deploys a pod on the cluster that invokes a certain method
provided by the search server.

Commands can be:
- fetch_sources
- extract_sources
- index_sources
"""
function k8s_run_pipeline_command(ctx, name, method)
    pod = kuber_obj(ctx, """{
        "apiVersion": "v1",
        "kind": "Pod",
        "metadata":{
            "name": "$name",
            "namespace": "default",
            "labels": {
                "name": "$name"
            }
        },
        "spec": {
            "containers": [{
                "name": "demo",
                "image": "demopipeline:v1",
                "args": ["$method"],
                "volumeMounts": [{
                    "name": "project",
                    "mountPath": "/project"
                }]
            }],
            "volumes": [{
                "name": "project",
                "hostPath": {
                    "path": "$projectdir"
                }
            }],
            "restartPolicy": "Never"
        }
    }""")
    k8s_run(ctx, pod)
end

k8s_fetch_sources(ctx) = k8s_run_pipeline_command(ctx, "fetch", "fetch_sources")
k8s_extract_sources(ctx) = k8s_run_pipeline_command(ctx, "extract", "extract_sources")
k8s_index_sources(ctx) = k8s_run_pipeline_command(ctx, "index", "index_sources")

"""
    k8s_run_search_server(ctx)

Deploy both
- the server as a pod
- a service that exposes it over a port
"""
function k8s_run_search_server(ctx)
    service = kuber_obj(ctx, """{
        "apiVersion": "v1",
        "kind": "Service",
        "metadata": {
            "name": "search",
            "namespace": "default",
            "labels": {"name": "search"}
        },
        "spec": {
            "type": "NodePort",
            "ports": [{
                "port": 5555,
                "nodePort": 30005
            }],
            "selector": {"name": "search"}
        }
    }""")
    k8s_run(ctx, service)

    pod = kuber_obj(ctx, """{
        "apiVersion": "v1",
        "kind": "Pod",
        "metadata":{
            "name": "search",
            "namespace": "default",
            "labels": {
                "name": "search"
            }
        },
        "spec": {
            "containers": [{
                "name": "demo",
                "image": "demopipeline:v1",
                "args": ["run_search_server"],
                "volumeMounts": [{
                    "name": "project",
                    "mountPath": "/project"
                }],
                "ports": [{"containerPort": 5555}]
            }],
            "volumes": [{
                "name": "project",
                "hostPath": {
                    "path": "$projectdir"
                }
            }],
            "restartPolicy": "Never"
        }
    }""")
    k8s_run(ctx, pod)
end

"""
    k8s_delete_search_server

Deletes both the search server pod and the service
"""
function k8s_delete_search_server(ctx::KuberContext=KuberContext())
    k8s_delete(ctx, :Pod, "search")
    k8s_delete(ctx, :Service, "search")
end

"""
    advance

Advances the pipeline between stages
"""
function advance(ctx::KuberContext, stage::Symbol)
    try
        if stage == :init
            stage = :fetching
            k8s_delete_search_server(ctx)
            k8s_fetch_sources(ctx)
        elseif stage == :fetching
            stage = :extracting
            k8s_delete(ctx, :Pod, "fetch")
            k8s_extract_sources(ctx)
        elseif stage == :extracting
            stage = :indexing
            k8s_delete(ctx, :Pod, "extract")
            k8s_index_sources(ctx)
        elseif stage == :indexing
            stage = :running
            k8s_delete(ctx, :Pod, "index")
            k8s_run_search_server(ctx)
        end
    catch ex
        @error("error handling event", exception=(ex,catch_backtrace()))
        # TODO: better error handling here
        # for the demo we just log
    end

    return stage
end

function can_advance(pod, stage)
    # We are interested in knowing when a Pod state is modified to "Succeeded".
    # In reality we should also monitor failure states for error handling.
    (pod.status.phase == "Succeeded") &&
    ((pod.metadata.name == "fetch"   && stage == :fetching) ||
     (pod.metadata.name == "extract" && stage == :extracting) ||
     (pod.metadata.name == "index"   && stage == :indexing))
end

"""
    k8s_update_search_server()

Run this periodically to refresh the search server.

Actions:
- fetch inputs
- extract inputs
- stop the search server if it is running
- index
- start the search server back up
"""
function k8s_update_search_server()
    ctx = KuberContext()
    Kuber.set_api_versions!(ctx)
    stage = :init
    println("starting")

    watch(ctx, list, :Pod) do stream
        for event in stream
            if isa(event, PodList)
                # watch is set up
                # the first event of a watch is where it returns the existing list of pods
                # we trigger the first step of the pipeline here
                stage = advance(ctx, stage)
            elseif isa(event, WatchEvent)
                # subsequent events are WatchEvents on individual pods
                # we are interestes only on pod state modification events
                pod = kuber_obj(ctx, event.object)
                if event.type == "MODIFIED"
                    print("$(pod.metadata.name) $(pod.status.phase)                    \r")
                    if can_advance(pod, stage)
                        stage = advance(ctx, stage)
                        if stage == :running
                            # we are done when our application is updated and reaches the running stage
                            close(stream)
                        end
                    end
                end
            end
        end
        println("")
        print("update complete!")
    end
end
