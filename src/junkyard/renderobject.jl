get_id(x::Integer) = x
get_id(x::RenderObject) = x.id


function delete_robj!(list, robj)
    for (i, id) in enumerate(list)
        if get_id(id) == robj.id
            splice!(list, i)
            return true, i
        end
    end
    false, 0
end


function GLAbstraction.robj_from_camera(window, camera)
    cam = window.cameras[camera]
    return filter(renderlist(window)) do robj
        robj[:projection] == cam.projection
    end
end

