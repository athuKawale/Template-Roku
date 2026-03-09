' Standard utility for task management

' Spawns a task, sets its fields, and observes the response
function TaskOrchestrator_RunTask(taskName as String, fields as Object, callback as String) as Object
    task = CreateObject("roSGNode", taskName)
    if task = invalid return invalid
    
    ' Set input fields
    for each key in fields
        task[key] = fields[key]
    end for
    
    ' Observe response (standard field name "response")
    task.observeField("response", callback)
    task.control = "RUN"
    
    return task
end function
