/**
 * Abstract interface for text embedding providers.
 * Implementations wrap OpenAI, Voyage, local models, etc.
 */
export interface EmbeddingProvider {
  /** Generate an embedding vector for a single text. */
  embed(text: string): Promise<number[]>;
  /** Generate embeddings for multiple texts in a batch. */
  embedBatch?(texts: string[]): Promise<number[][]>;
  /** Dimensionality of the embedding vectors. */
  dimensions: number;
}
