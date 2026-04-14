sub init()
    m.statusLabel = m.top.findNode("statusLabel")
    ' TEMPLATE: Replace with your initial API call and UI binding.
    ' Expected flow:
    ' 1) Call TaskOrchestrator_RunTask with ApiTask and request params.
    ' 2) In onApiResponse, set m.top.selectedItem when the user selects an item.
    m.statusLabel.text = "Template ready. Waiting for data..."
end sub

' TEMPLATE STUB: Replace with your API response handler.
' sub onApiResponse(event as Object)
'     response = event.getData()
'     if response.success = true
'         ' Process data
'     else
'         m.statusLabel.text = "Error: " + response.error
'     end if
' end sub
