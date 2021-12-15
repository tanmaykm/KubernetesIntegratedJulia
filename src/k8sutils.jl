using Kuber

const projectdir = dirname(@__DIR__)

const Pod = Kuber.Typedefs.CoreV1.Pod
const Service = Kuber.Typedefs.CoreV1.Service
const PodList = Kuber.Typedefs.CoreV1.PodList
const WatchEvent = Kuber.Typedefs.CoreV1.WatchEvent

function k8s_run(ctx::KuberContext, typ::Symbol, entity)
    @debug("putting", typ, name=entity.metadata.name)
    put!(ctx, entity)
end
k8s_run(ctx::KuberContext, entity::Pod) = k8s_run(ctx, :Pod, entity)
k8s_run(ctx::KuberContext, entity::Service) = k8s_run(ctx, :Service, entity)

function k8s_delete(ctx::KuberContext, typ::Symbol, name::String)
    @debug("deleting", typ, name)
    try
        delete!(ctx, typ, name)
    catch
        # ignore not found exceptions
    end
end

function k8s_run_command(ctx, name, method)
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

k8s_fetch_sources(ctx) = k8s_run_command(ctx, "fetch", "fetch_sources")
k8s_extract_sources(ctx) = k8s_run_command(ctx, "extract", "extract_sources")
k8s_index_sources(ctx) = k8s_run_command(ctx, "index", "index_sources")

function k8s_run_search_server(ctx)
    service = kuber_obj(ctx, """{
        "apiVersion": "v1",
        "kind": "Service",
        "metadata": {
            "name": "searchsvc",
            "namespace": "default",
            "labels": {"name": "searchsvc"}
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
    pipeline_state = :init
    println("starting")

    watch(ctx, list, :Pod) do stream
        k8s_delete(ctx, :Pod, "search")
        k8s_delete(ctx, :Service, "searchsvc")

        for event in stream
            try
                #@info("got event", typ=typeof(event))
                if isa(event, WatchEvent)
                    entity = kuber_obj(ctx, event.object)
                    if isa(entity, Pod)
                        pod = entity
                        #@info("got pod event", typ=event.type, pod=pod.metadata.name)
                        if event.type == "MODIFIED"
                            # we are interested in knowing when a Pod state is modified to "Succeeded"
                            print("$(pod.metadata.name) $(pod.status.phase)                    \r")
                            if pod.status.phase == "Succeeded"
                                if pod.metadata.name == "fetch"
                                    if pipeline_state == :fetching
                                        pipeline_state = :extracting
                                        k8s_delete(ctx, :Pod, "fetch")
                                        @debug("fetch done, starting extract")
                                        k8s_extract_sources(ctx)
                                    end
                                elseif pod.metadata.name == "extract"
                                    if pipeline_state == :extracting
                                        pipeline_state = :indexing
                                        k8s_delete(ctx, :Pod, "extract")
                                        @debug("fetch done, starting index")
                                        k8s_index_sources(ctx)
                                    end
                                elseif pod.metadata.name == "index"
                                    if pipeline_state == :indexing
                                        pipeline_state = :running
                                        k8s_delete(ctx, :Pod, "index")
                                        @debug("index done, restarting search server")
                                        k8s_run_search_server(ctx)
                                        @debug("search server started, closing stream")
                                        close(stream)
                                    end
                                end
                            end
                        end
                    end
                elseif isa(event, PodList)
                    # watch is set up, this is the first event of a watch where it returns the existing list of pods
                    # this is where we trigger the first step of the pipeline
                    if pipeline_state == :init
                        @debug("starting fetch")
                        pipeline_state = :fetching
                        k8s_fetch_sources(ctx)
                    end
                end
                @debug("pipeline state: $pipeline_state")
            catch ex
                @error("error handling event", exception=(ex,catch_backtrace()))
            end
        end
        println("")
        print("update complete!")
    end
end