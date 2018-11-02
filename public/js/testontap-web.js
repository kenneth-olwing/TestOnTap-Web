var currentUploadMsg;
var currentSuiteJson;
var interval;

$(document).ready
	(
		function()
		{
			resetInput('inpUpload');
			$('#btnUpload').click(uploadButtonFunc);
			$('#uploadMsg').empty();
			$('#uploadMsg').click(showCurrentUploadMsgFunc);
			$('#suitestitle').click(updateSuiteTree);
			updateSuiteTree(true);
			
			var val = getCookieValue('autoupd');
			var autoupd = $('#autoupd');
			autoupd.prop('checked', val == 1);
			if (val == 1)
				interval = setInterval(updateSuiteTree, 30000);
			autoupd.click(function()
				{
					if (autoupd.is(':checked'))
					{
						interval = setInterval(updateSuiteTree, 30000);
						document.cookie = "autoupd=1";
					}
					else
					{
						clearInterval(interval);
						document.cookie = "autoupd=0";
					}
				});
		}
	);

function updateSuiteTree(firstTime)
{
	$.ajax
	(
		{
			url : '/api/v1/isparseractive',
			type : 'POST',
			success : function(active)
			{
				if (active == 1)
					$('#activemsg').html("<hr/>NOTE: results are being processed!");
				else
					$('#activemsg').html("");
			}
		}
	);
	
	$.ajax
	(
		{
			url : '/api/v1/suites',
			success : function(json)
				{
					var strJson = JSON.stringify(json)
					if (strJson != currentSuiteJson)
					{
						var obj = $.jstree.reference('#suitenavtree');
						if (obj != null)
							obj.destroy();
						var jqe = $('#suitenavtree');
						var tree = jqe.jstree
							(
								{
									core:
										{
											multiple: false,
											data: json,
											themes:
												{
													icons: false,
													variant: "small"
												}
										},
									plugins: [ 'wholerow', 'sort' ]
								}
							);
						
						jqe.on('select_node.jstree', function(node, selected, event)
								{
									var node = selected.node;
									switch(node.data.type)
									{
										case 'suite':
											renderSuite(node);
											break;
										case 'result':
											renderResult(node);
											break;
										case 'test':
											renderTest(node);
											break;
										case 'suiteartifacts':
											renderSuiteArtifacts(node);
											break;
										case 'suiteartifactstop':
											renderSuiteArtifactsTop(node);
											break;
										default:
											alert("UNKNOWN");
									}
								}
							);
						
						if (firstTime)
						{
							jqe.on('ready.jstree', function(e, data)
									{
										data.instance.select_node(data.instance.get_node(json[0].id));
										jqe.off('ready.jstree');
									}
								);
						}
						
						currentSuiteJson = strJson;
					}
				},
//			error : function(data, status, error)
//				{
//					console.log("Error fetching suites : " + error);
//					var obj = $.jstree.reference('#suitenavtree');
//					if (obj != null)
//						obj.destroy();
//				}
		}
	);
}

function renderSuite(node)
{
	$('#infotitle').text(node.data.name);
	$.ajax(
			{
				url : '/api/v1/render/' + node.data.type,
				type : 'POST',
				data : JSON.stringify(node.data),
				contentType: "application/json; charset=utf-8",
				success : function(html)
					{
						$('#infobox').html(html);
					}
			});
}

function renderResult(node)
{
	$('#infotitle').text(node.data.suitename + " result '" + node.data.timestamp + "' (run id: " + node.id + ")");
	$.ajax(
			{
				url : '/api/v1/render/' + node.data.type,
				type : 'POST',
				data : JSON.stringify(node.data),
				contentType: "application/json; charset=utf-8",
				success : function(html)
					{
						$('#infobox').html(html);
					}
			});
}

function renderTest(node)
{
	var tree = $('#suitenavtree').jstree(true)
	var result = tree.get_node(node.parent);
	var nd = node.data;
	nd.zipfile = result.data.zipfile;
	$('#infotitle').text(result.data.suitename + " " + result.data.timestamp + " test '" + nd.name + "'");
	$.ajax(
			{
				url : '/api/v1/render/' + nd.type,
				type : 'POST',
				data : JSON.stringify(nd),
				contentType: "application/json; charset=utf-8",
				success : function(html)
					{
						$('#infobox').html(html);
					}
			});
}

function renderSuiteArtifacts(node)
{
	var tree = $('#suitenavtree').jstree(true)
	var test = tree.get_node(node.parent);
	var result = tree.get_node(test.parent);
	var nd = node.data;
	nd.zipfile = result.data.zipfile;
	nd.name = test.data.name;
	$('#infotitle').text("Suite artifacts from '" + test.data.name + "'");
	$.ajax(
			{
				url : '/api/v1/render/' + nd.type,
				type : 'POST',
				data : JSON.stringify(nd),
				contentType: "application/json; charset=utf-8",
				success : function(html)
					{
						$('#infobox').html(html);
					}
			});
}

function renderSuiteArtifactsTop(node)
{
	var tree = $('#suitenavtree').jstree(true)
	var test = tree.get_node(node.parent);
	var nd = node.data;
	nd.zipfile = test.data.zipfile;
	$('#infotitle').text("All suite artifacts from '" + test.data.suitename + "'");
	$.ajax(
			{
				url : '/api/v1/render/' + nd.type,
				type : 'POST',
				data : JSON.stringify(nd),
				contentType: "application/json; charset=utf-8",
				success : function(html)
					{
						$('#infobox').html(html);
					}
			});
}

function showCurrentUploadMsgFunc()
{
	var msg = currentUploadMsg + "\n\nClear message?";
	if (confirm(msg))
		$('#uploadMsg').empty();
}

function resetInput(inpId)
{
	var el = $('#' + inpId);
	el.wrap('<form>').closest('form').get(0).reset();
	el.unwrap();
}

function uploadButtonFunc()
{
	var files = $('#inpUpload')[0].files;

	if (files.length == 0)
		return;

	for (var i = 0; i < files.length ; i++)
	{
		var file = files.item(i);
		if (file.type !== 'application/x-zip-compressed')
		{
			alert("Test results are expected to be zip files: " + file.name);
			return;
		}
	}

	$('#uploadMsg').text("UPLOADING...");
	var formData = new FormData($("#uploadForm")[0]);
	$.ajax({
		url : '/api/v1/upload',
		type : 'POST',
		data : formData,
		processData : false,
		contentType : false,
		success : function(data) {
			resetInput('inpUpload');
			var obj = JSON.parse(data);
			var basemsg = obj.msg;
			var fullmsg = basemsg;
			if (obj.result != 0)
			{
				fullmsg += "\n\n";
				for (key in obj.files)
				{
					fullmsg += obj.files[key].msg + " (" + key + ")\n";
				}
				alert(fullmsg);
			}
			currentUploadMsg = fullmsg;
			$('#uploadMsg').text(basemsg);
			$('#suitestitle').click(updateSuiteTree);
		}
	});
}

function getCookieValue(a)
{
    var b = document.cookie.match('(^|;)\\s*' + a + '\\s*=\\s*([^;]+)');
    return b ? b.pop() : '';
}
