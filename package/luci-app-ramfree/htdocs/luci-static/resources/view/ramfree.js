'use strict';
'require fs';
'require view';
'require dom';

function parseMemAvailable(text) {
	var m = (text || '').match(/MemAvailable:\s+(\d+)\s+kB/);
	return m ? parseInt(m[1], 10) : null;
}

function mb(kb) {
	return (kb != null) ? (kb / 1024).toFixed(1) + ' MB' : '-';
}

return view.extend({
	handleSaveApply: null,
	handleSave: null,
	handleReset: null,

	load: function() {
		var before = null;

		return L.resolveDefault(fs.exec_direct('/bin/cat', ['/proc/meminfo']), null)
			.then(function(text) {
				before = parseMemAvailable(text);

				return Promise.all([
					L.resolveDefault(fs.exec('/bin/sync', null), null),
					L.resolveDefault(fs.exec('/sbin/sysctl', ['-w', 'vm.drop_caches=3']), null)
				]);
			})
			.then(function() {
				return L.resolveDefault(fs.exec_direct('/bin/cat', ['/proc/meminfo']), null);
			})
			.then(function(text) {
				return {
					before: before,
					after: parseMemAvailable(text)
				};
			});
	},

	render: function(data) {
		var before = data ? data.before : null;
		var after = data ? data.after : null;
		var freed = (before != null && after != null) ? (after - before) : null;

		return E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, _('Freeping Memory Cache')),
			E('table', { 'class': 'table' }, [
				E('tr', { 'class': 'tr' }, [
					E('td', { 'class': 'td left', 'width': '33%' }, _('MemAvailable before')),
					E('td', { 'class': 'td left' }, mb(before))
				]),
				E('tr', { 'class': 'tr' }, [
					E('td', { 'class': 'td left', 'width': '33%' }, _('MemAvailable after')),
					E('td', { 'class': 'td left' }, mb(after))
				]),
				E('tr', { 'class': 'tr' }, [
					E('td', { 'class': 'td left', 'width': '33%' }, _('Freed')),
					E('td', { 'class': 'td left' }, mb(freed))
				])
			]),
			E('div', { 'class': 'right', 'style': 'margin-top: 1em' }, [
				E('button', {
					'class': 'btn cbi-button',
					'click': function() { window.location.href = '/cgi-bin/luci/'; }
				}, _('Back to overview'))
			])
		]);
	}
});
