nextflow.preview.dsl=2

import static groovy.json.JsonOutput.*

include '../../utils/processes/utils.nf'

/* 
 * STATIC VERSION GENERATE REPORT
 * 
 * General reporting function: 
 * takes a template ipynb and adata as input,
 * outputs ipynb named by the value in ${reportTitle}
 */
process SC__SCANPY__GENERATE_REPORT {

  	container params.sc.scanpy.container
  	clusterOptions "-l nodes=1:ppn=2 -l pmem=30gb -l walltime=1:00:00 -A ${params.global.qsubaccount}"
  	publishDir "${params.global.outdir}/notebooks/intermediate", mode: 'link', overwrite: true
	maxForks 2

	input:
		file ipynb
		tuple val(sampleId), path(adata)
		val(reportTitle)

	output:
		tuple val(sampleId), path("${sampleId}.${reportTitle}.ipynb")

	script:
		def paramsCopy = params.findAll({!["parseConfig", "parse-config"].contains(it.key)})
		"""
		papermill ${ipynb} \
		    --report-mode \
			${sampleId}.${reportTitle}.ipynb \
			-p FILE $adata \
			-p WORKFLOW_MANIFEST '${toJson(workflow.manifest)}' \
			-p WORKFLOW_PARAMETERS '${toJson(paramsCopy)}'
		"""

}

/* 
 * PARAMETER EXPLORATION VERSION OF SCANPY CLUSTERING GENERATE REPORT
 * 
 * General reporting function: 
 * takes a template ipynb and adata as input,
 * outputs ipynb named by the value in ${reportTitle}
 */
process SC__SCANPY__PARAM_EXPLORE_CLUSTERING_GENERATE_REPORT {

  	container params.sc.scanpy.container
  	clusterOptions "-l nodes=1:ppn=2 -l pmem=30gb -l walltime=1:00:00 -A ${params.global.qsubaccount}"
  	publishDir "${params.global.outdir}/notebooks/intermediate/clustering/${isParamNull(method) ? "default": method.toLowerCase()}/${isParamNull(resolution) ? "res_": resolution}", mode: 'symlink', overwrite: true
	maxForks 2

	input:
		file ipynb
		tuple \
			val(sampleId), \
			path(adata), \
			val(method), \
			val(resolution)
		val(reportTitle)

	output:
		tuple \
			val(sampleId), \
			path("${sampleId}.${reportTitle}.${uuid}.ipynb"), \
			val(method), \
			val(resolution)

	script:
		def paramsCopy = params.findAll({!["parseConfig", "parse-config"].contains(it.key)})
		// In parameter exploration mode, file output needs to be tagged with a unique identitifer because of:
		// - https://github.com/nextflow-io/nextflow/issues/470
		stashedParams = [method, resolution]
		if(!isParamNull(stashedParams))
			uuid = stashedParams.findAll { it != 'NULL' }.join('_')
		"""
		papermill ${ipynb} \
		    --report-mode \
			${sampleId}.${reportTitle}.${uuid}.ipynb \
			-p FILE $adata \
			-p WORKFLOW_MANIFEST '${toJson(workflow.manifest)}' \
			-p WORKFLOW_PARAMETERS '${toJson(paramsCopy)}'
		"""

}

// QC report takes two inputs, so needs it own process
process SC__SCANPY__GENERATE_DUAL_INPUT_REPORT {

	container params.sc.scanpy.container
	clusterOptions "-l nodes=1:ppn=2 -l pmem=30gb -l walltime=1:00:00 -A ${params.global.qsubaccount}"
	publishDir "${params.global.outdir}/notebooks/intermediate", mode: 'link', overwrite: true
	maxForks 2

  	input:
		file(ipynb)
		tuple \
			val(sampleId), \
			file(data1), \
			file(data2), \
			val(stashedParams)
		val(reportTitle)
		val(isParameterExplorationModeOn)

  	output:
    	tuple \
			val(sampleId), \
			file("${sampleId}.${reportTitle}.${isParameterExplorationModeOn ? uuid + "." : ''}ipynb"), \
			val(stashedParams)

  	script:
		if(!isParamNull(stashedParams))
			uuid = stashedParams.findAll { it != 'NULL' }.join('_')
		"""
		papermill ${ipynb} \
		    --report-mode \
			${sampleId}.${reportTitle}.${isParameterExplorationModeOn ? uuid + "." : ''}ipynb \
			-p FILE1 $data1 -p FILE2 $data2 \
			-p WORKFLOW_MANIFEST '${toJson(workflow.manifest)}' \
			-p WORKFLOW_PARAMETERS '${toJson(paramsCopy)}'
		"""

}

process SC__SCANPY__REPORT_TO_HTML {

	container params.sc.scanpy.container
	clusterOptions "-l nodes=1:ppn=2 -l pmem=30gb -l walltime=1:00:00 -A ${params.global.qsubaccount}"
	publishDir "${params.global.outdir}/notebooks/intermediate", mode: 'link', overwrite: true
	// copy final "merged_report" to notbooks root:
	publishDir "${params.global.outdir}/notebooks", pattern: '*merged_report*', mode: 'link', overwrite: true
	maxForks 2

	input:
		tuple val(sampleId), path(ipynb)

	output:
		file("*.html")

	script:
		"""
		jupyter nbconvert ${ipynb} --to html
		"""

}

process SC__SCANPY__MERGE_REPORTS {

	container params.sc.scanpy.container
	clusterOptions "-l nodes=1:ppn=2 -l pmem=30gb -l walltime=1:00:00 -A ${params.global.qsubaccount}"
	publishDir "${params.global.outdir}/notebooks/intermediate", mode: 'link', overwrite: true
	// copy final "merged_report" to notebooks root:
	publishDir "${params.global.outdir}/notebooks", pattern: '*merged_report*', mode: 'link', overwrite: true
	maxForks 2

	input:
		tuple \
			val(sampleId), \
			path(ipynbs), \
			val(stashedParams)
		val(reportTitle)
		val(isParameterExplorationModeOn)

	output:
		tuple val(sampleId), path("${sampleId}.${reportTitle}.${isParameterExplorationModeOn ? uuid + '.' : ''}ipynb")

	script:
		if(!isParamNull(stashedParams))
			uuid = stashedParams.findAll { it != 'NULL' }.join('_')
		"""
		nbmerge \
			${ipynbs} \
			-o "${sampleId}.${reportTitle}.${isParameterExplorationModeOn ? uuid + '.' : ''}ipynb"
		"""

}
