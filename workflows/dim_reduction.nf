nextflow.preview.dsl=2

//////////////////////////////////////////////////////
//  process imports:

// scanpy:
include DIM_REDUCTION_PCA from './dim_reduction_pca' params(params)
// include SC__SCANPY__DIM_REDUCTION as SC__SCANPY__DIM_REDUCTION__PCA from '../processes/dim_reduction.nf' params(params + [method: "pca"])
include SC__SCANPY__DIM_REDUCTION as SC__SCANPY__DIM_REDUCTION__TSNE from '../processes/dim_reduction.nf' params(params + [method: "tsne"])
include SC__SCANPY__DIM_REDUCTION as SC__SCANPY__DIM_REDUCTION__UMAP from '../processes/dim_reduction.nf' params(params + [method: "umap"])

// reporting:
include GENERATE_REPORT from './create_report.nf' params(params)

//////////////////////////////////////////////////////

workflow DIM_REDUCTION {

    take:
        data

    main:
        dimred_pca = DIM_REDUCTION_PCA( data )
        dimred_pca_tsne = SC__SCANPY__DIM_REDUCTION__TSNE( DIM_REDUCTION_PCA.out.map {
                item -> tuple(item[0], item[1], null, null)
        })
        dimred_pca_tsne_umap = SC__SCANPY__DIM_REDUCTION__UMAP( SC__SCANPY__DIM_REDUCTION__TSNE.out.map {
                item -> tuple(item[0], item[1], null, null)
        })

        report = GENERATE_REPORT(
            "DIMENSIONALITY_REDUCTION",
            SC__SCANPY__DIM_REDUCTION__UMAP.out.map { it -> tuple(it[0], it[1]) },
            file(workflow.projectDir + params.sc.scanpy.dim_reduction.report_ipynb),
            false
        )

    emit:
        dimred_pca_tsne
        dimred_pca_tsne_umap
        report

}
