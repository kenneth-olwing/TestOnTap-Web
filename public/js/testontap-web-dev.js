$(document).ready
	(
		function()
		{
			$('#btnKickParser').click(function() 
				{
					$.ajax
					(
						{
							url : '/development/kickparser',
							type : 'POST'
						}
					)
				});
			$('#btnSwitchAutoUpd').click(function() 
					{
						var val = getCookieValue('autoupd');
						console.log("Current: " + val);
						val = (val == 1 ? 0 : 1);
						console.log("New: " + val);
						document.cookie = "autoupd=" + val;
					});
		}
	);
